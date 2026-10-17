import { Injectable } from '@nestjs/common';
import { RedisService } from '../infra/redis.service.js';
import { DeskStore } from '../library/desk-store.js';
import {
  LIBRARY_LAYOUT,
  LayoutDesk,
} from '../library/layout/library-layout.js';
import { ReaderSession } from '../library/library.service.js';
import { RoomDirectory } from '../library/room-directory.js';
import { ModerationService } from '../moderation/moderation.service.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';

/** How long a request waits for a partner before the device gives up. */
export const MATCH_WAIT_SECONDS = 120;

const queueKey = (focusMinutes: number) => `match:queue:${focusMinutes}`;
const waitingKey = (userId: string) => `match:waiting:${userId}`;

interface Waiting {
  userId: string;
  displayName: string;
  avatarSpriteId: string;
  categoryKey: string;
}

export interface MatchFound {
  roomId: string;
  deskId: string;
  focusMinutes: number;
  breakMinutes: number;
  categoryKey: string;
  partner: { id: string; displayName: string; avatarSpriteId: string };
}

/**
 * "Find me a study buddy": readers asking for the same pomodoro length are paired and sent to two
 * neighbouring desks in a hall with space, to start together. No talking needed, just company.
 * A reader waits in a Redis queue; a partner claims them with GETDEL, so one waiting reader is
 * never matched twice.
 */
@Injectable()
export class MatchService {
  constructor(
    private readonly redis: RedisService,
    private readonly directory: RoomDirectory,
    private readonly desks: DeskStore,
    private readonly moderation: ModerationService,
    private readonly bus: RoomEventBus,
  ) {}

  async request(
    session: ReaderSession,
    focusMinutes: number,
    categoryKey: string,
  ): Promise<'WAITING' | 'MATCHED'> {
    const me = session.user;
    await this.cancel(me.id);
    const separated = new Set(await this.moderation.separatedIds(me.id));
    const skipped: string[] = [];
    let partner: Waiting | null = null;

    for (;;) {
      const candidateId = await this.redis.client.lpop(queueKey(focusMinutes));
      if (!candidateId) break;
      if (candidateId === me.id) continue;
      if (separated.has(candidateId)) {
        skipped.push(candidateId);
        continue;
      }
      const claimed = await this.redis.client.getdel(waitingKey(candidateId));
      if (claimed) {
        partner = JSON.parse(claimed) as Waiting;
        break;
      }
    }
    // Readers we could not pair with stay in line for someone else.
    if (skipped.length)
      await this.redis.client.lpush(
        queueKey(focusMinutes),
        ...skipped.reverse(),
      );

    if (!partner) {
      const waiting: Waiting = {
        userId: me.id,
        displayName: me.displayName,
        avatarSpriteId: me.avatarSpriteId,
        categoryKey,
      };
      await this.redis.client
        .multi()
        .set(
          waitingKey(me.id),
          JSON.stringify(waiting),
          'EX',
          MATCH_WAIT_SECONDS,
        )
        .rpush(queueKey(focusMinutes), me.id)
        .expire(queueKey(focusMinutes), MATCH_WAIT_SECONDS * 2)
        .exec();
      return 'WAITING';
    }

    const now = Date.now();
    const roomId = await this.directory.assignHall(now);
    const [first, second] = this.neighbouringDesks(
      new Set((await this.desks.list(roomId)).map((desk) => desk.deskId)),
    );
    const breakMinutes = focusMinutes >= 50 ? 10 : 5;
    await Promise.all([
      this.tell(partner.userId, {
        roomId,
        deskId: first,
        focusMinutes,
        breakMinutes,
        categoryKey: partner.categoryKey,
        partner: {
          id: me.id,
          displayName: me.displayName,
          avatarSpriteId: me.avatarSpriteId,
        },
      }),
      this.tell(me.id, {
        roomId,
        deskId: second,
        focusMinutes,
        breakMinutes,
        categoryKey,
        partner: {
          id: partner.userId,
          displayName: partner.displayName,
          avatarSpriteId: partner.avatarSpriteId,
        },
      }),
    ]);
    return 'MATCHED';
  }

  /** Stops waiting; the queue entry is skipped lazily by whoever reaches it. */
  async cancel(userId: string): Promise<void> {
    await this.redis.client.del(waitingKey(userId));
  }

  /** Two free desks side by side in one row, or the two free desks closest together. */
  private neighbouringDesks(taken: Set<string>): [string, string] {
    const free = LIBRARY_LAYOUT.desks.filter((desk) => !taken.has(desk.deskId));
    let best: [LayoutDesk, LayoutDesk] | null = null;
    let bestDistance = Infinity;
    for (let i = 0; i < free.length; i++) {
      for (let j = i + 1; j < free.length; j++) {
        const distance =
          Math.abs(free[i].tileX - free[j].tileX) +
          Math.abs(free[i].tileY - free[j].tileY) * 3;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = [free[i], free[j]];
        }
      }
    }
    // A hall is assigned only while it has room, so two free desks exist in practice.
    const [a, b] = best ?? [LIBRARY_LAYOUT.desks[0], LIBRARY_LAYOUT.desks[1]];
    return [a.deskId, b.deskId];
  }

  /** Delivered only to `userId`, through a channel no one views. */
  private async tell(userId: string, match: MatchFound): Promise<void> {
    await this.bus.publish(`user:${userId}`, ServerEvent.matchFound, {
      userId,
      match,
    });
  }
}
