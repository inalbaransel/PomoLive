import { Injectable } from '@nestjs/common';
import type { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../infra/prisma.service.js';
import { RedisService } from '../infra/redis.service.js';
import { ReaderSession } from '../library/library.service.js';
import { RoomDirectory } from '../library/room-directory.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { RoomsRepository } from '../rooms/rooms.repository.js';
import { PublicUser } from '../users/user.js';

/** Messages a reader may send per window; generous for talk, tight against floods and scripts. */
const SEND_LIMIT = 8;
const SEND_WINDOW_SECONDS = 10;
/** At most one typing ping per reader per room every this many ms. */
const TYPING_INTERVAL_MS = 2_500;
const PAGE_SIZE = 50;

export interface ChatMessageView {
  id: string;
  clientId: string;
  roomId: string;
  user: PublicUser;
  body: string;
  createdAt: number;
}

export interface ChatPage {
  /** Oldest first. */
  messages: ChatMessageView[];
  hasMore: boolean;
}

const messageSelect = {
  id: true,
  clientId: true,
  roomId: true,
  body: true,
  createdAt: true,
  user: {
    select: {
      id: true,
      username: true,
      displayName: true,
      avatarSpriteId: true,
    },
  },
} as const;

type MessageRow = Prisma.ChatMessageGetPayload<{
  select: typeof messageSelect;
}>;

/**
 * Room chat. Each message is one indexed insert plus one pub/sub publish that reaches only the
 * sockets looking at the room, so load grows with what people say, not with how many listen.
 * Per-reader rate limits in Redis keep a flood or a script from swamping the room or the database.
 */
@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly bus: RoomEventBus,
    private readonly rooms: RoomsRepository,
  ) {}

  async send(
    session: ReaderSession,
    body: string,
    clientId: string,
  ): Promise<ChatMessageView> {
    const roomId = this.requireRoom(session);
    // A retry of a message that already went through gets the original back, not a second copy.
    const existing = await this.prisma.chatMessage.findUnique({
      where: { userId_clientId: { userId: session.user.id, clientId } },
      select: messageSelect,
    });
    if (existing) return ChatService.view(existing);

    await this.enforceRateLimit(session.user.id);
    const row = await this.prisma.chatMessage.create({
      data: { roomId, userId: session.user.id, body, clientId },
      select: messageSelect,
    });
    const message = ChatService.view(row);
    await this.bus.publish(roomId, ServerEvent.chatMessage, { message });
    return message;
  }

  /** The latest page, or the page before `before` (ms epoch) when scrolling back. */
  async history(session: ReaderSession, before?: number): Promise<ChatPage> {
    const roomId = this.requireRoom(session);
    const rows = await this.prisma.chatMessage.findMany({
      where: {
        roomId,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: PAGE_SIZE + 1,
      select: messageSelect,
    });
    return {
      messages: rows.slice(0, PAGE_SIZE).reverse().map(ChatService.view),
      hasMore: rows.length > PAGE_SIZE,
    };
  }

  /** Authors delete their own messages; owners of a user room may delete any message in it. */
  async delete(session: ReaderSession, messageId: string): Promise<void> {
    const roomId = this.requireRoom(session);
    const message =
      (await this.prisma.chatMessage.findUnique({
        where: { id: messageId },
        select: { roomId: true, userId: true },
      })) ?? ProtocolError.throw('MESSAGE_NOT_FOUND', 'Message is gone');
    if (message.roomId !== roomId)
      ProtocolError.throw('MESSAGE_NOT_FOUND', 'Message is gone');
    if (message.userId !== session.user.id) {
      const room = RoomDirectory.isHallId(roomId)
        ? null
        : await this.rooms.findById(roomId);
      if (room?.ownerId !== session.user.id)
        ProtocolError.throw('FORBIDDEN', 'Only the author or owner can delete');
    }
    await this.prisma.chatMessage.deleteMany({ where: { id: messageId } });
    await this.bus.publish(roomId, ServerEvent.chatDeleted, { messageId });
  }

  /** Tells the room someone is typing, at most once per interval per reader. */
  async typing(session: ReaderSession): Promise<void> {
    const roomId = this.requireRoom(session);
    const fresh = await this.redis.client.set(
      `chat:typing:${roomId}:${session.user.id}`,
      '1',
      'PX',
      TYPING_INTERVAL_MS,
      'NX',
    );
    if (!fresh) return;
    await this.bus.publish(roomId, ServerEvent.chatTyping, {
      user: {
        id: session.user.id,
        username: session.user.username,
        displayName: session.user.displayName,
        avatarSpriteId: session.user.avatarSpriteId,
      },
    });
  }

  /** Drops a deleted room's conversation. */
  async clear(roomId: string): Promise<void> {
    await this.prisma.chatMessage.deleteMany({ where: { roomId } });
  }

  private requireRoom(session: ReaderSession): string {
    return (
      session.roomId ?? ProtocolError.throw('NOT_IN_ROOM', 'Open a room first')
    );
  }

  private async enforceRateLimit(userId: string): Promise<void> {
    const window = Math.floor(Date.now() / (SEND_WINDOW_SECONDS * 1000));
    const key = `chat:rate:${userId}:${window}`;
    const [[, count]] = (await this.redis.client
      .multi()
      .incr(key)
      .expire(key, SEND_WINDOW_SECONDS * 2)
      .exec()) as [[Error | null, number], unknown];
    if (count > SEND_LIMIT)
      ProtocolError.throw('RATE_LIMITED', 'Slow down a little');
  }

  private static view(row: MessageRow): ChatMessageView {
    return {
      id: row.id,
      clientId: row.clientId,
      roomId: row.roomId,
      user: row.user,
      body: row.body,
      createdAt: row.createdAt.getTime(),
    };
  }
}
