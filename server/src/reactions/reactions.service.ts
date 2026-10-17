import { Injectable } from '@nestjs/common';
import { RedisService } from '../infra/redis.service.js';
import { LibraryService, ReaderSession } from '../library/library.service.js';
import { ModerationService } from '../moderation/moderation.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { Reaction } from './reactions.js';

/** One reaction per sender and desk in this window, so encouragement never turns into noise. */
const COOLDOWN_SECONDS = 20;

/**
 * Silent encouragement in a room: a clap or a coffee left on someone's desk, seen by everyone in
 * the room as a little rising emoji, and by the desk's owner wherever they are in the app.
 */
@Injectable()
export class ReactionsService {
  constructor(
    private readonly library: LibraryService,
    private readonly moderation: ModerationService,
    private readonly redis: RedisService,
    private readonly bus: RoomEventBus,
  ) {}

  async react(
    session: ReaderSession,
    deskId: string,
    reaction: Reaction,
  ): Promise<void> {
    const desk = await this.library.occupiedDesk(session, deskId);
    if (desk.userId === session.user.id)
      ProtocolError.throw('FORBIDDEN', 'You cannot react to your own desk');
    if (await this.moderation.isSeparated(session.user.id, desk.userId))
      ProtocolError.throw('DESK_NOT_FOUND', 'Nobody sits at this desk');
    const fresh = await this.redis.client.set(
      `react:${session.user.id}:${desk.userId}`,
      '1',
      'EX',
      COOLDOWN_SECONDS,
      'NX',
    );
    if (!fresh) ProtocolError.throw('RATE_LIMITED', 'Give it a moment');
    await this.bus.publish(session.roomId!, ServerEvent.deskReaction, {
      deskId,
      reaction,
      // The desk's owner hears it from any screen.
      userId: desk.userId,
      from: {
        id: session.user.id,
        displayName: session.user.displayName,
        avatarSpriteId: session.user.avatarSpriteId,
      },
    });
  }
}
