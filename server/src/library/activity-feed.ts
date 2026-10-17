import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { PrismaService } from '../infra/prisma.service.js';
import { RedisService } from '../infra/redis.service.js';
import { DeskRecord, RoomState } from './library.types.js';

const FEED_KEY = 'feed:recent';
const FEED_LENGTH = 40;
/** Only sessions at least this long make the feed when they end. */
const FINISHED_MIN_MS = 25 * 60_000;

export interface FeedItem {
  id: string;
  kind: 'STARTED' | 'FINISHED';
  user: { id: string; displayName: string; avatarSpriteId: string };
  category: CategoryInfo;
  roomId: string;
  roomName: string;
  /** Minutes focused, for `FINISHED`. */
  minutes: number | null;
  at: number;
}

/**
 * What just happened in the open library: who sat down and who finished a long session, in halls
 * and public rooms only. A short capped list in Redis, read when the Odalar tab refreshes.
 */
@Injectable()
export class ActivityFeed {
  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
  ) {}

  async started(
    room: RoomState | null,
    desk: DeskRecord,
    now: number,
  ): Promise<void> {
    await this.push(room, desk, 'STARTED', null, now);
  }

  async finished(
    room: RoomState | null,
    desk: DeskRecord,
    focusedMs: number,
    now: number,
  ): Promise<void> {
    if (focusedMs < FINISHED_MIN_MS) return;
    await this.push(
      room,
      desk,
      'FINISHED',
      Math.floor(focusedMs / 60_000),
      now,
    );
  }

  /** Newest first, without readers the viewer is separated from, and without the focus time of those who hide it. */
  async recent(
    viewerId: string,
    hidden: string[],
    limit = 20,
  ): Promise<FeedItem[]> {
    const raw = await this.redis.client.lrange(FEED_KEY, 0, FEED_LENGTH - 1);
    const items = raw
      .map((entry) => JSON.parse(entry) as FeedItem)
      .filter(
        (item) => item.user.id !== viewerId && !hidden.includes(item.user.id),
      );
    const finishers = [
      ...new Set(
        items
          .filter((item) => item.kind === 'FINISHED')
          .map((item) => item.user.id),
      ),
    ];
    const private_ = finishers.length
      ? new Set(
          (
            await this.prisma.user.findMany({
              where: { id: { in: finishers }, statsVisible: false },
              select: { id: true },
            })
          ).map((user) => user.id),
        )
      : new Set<string>();
    return items
      .filter((item) => item.kind === 'STARTED' || !private_.has(item.user.id))
      .slice(0, limit);
  }

  private async push(
    room: RoomState | null,
    desk: DeskRecord,
    kind: FeedItem['kind'],
    minutes: number | null,
    now: number,
  ): Promise<void> {
    if (!room || room.kind === 'PRIVATE') return;
    const item: FeedItem = {
      id: randomUUID(),
      kind,
      user: {
        id: desk.userId,
        displayName: desk.userName,
        avatarSpriteId: desk.avatarSpriteId,
      },
      category: desk.category,
      roomId: room.id,
      roomName: room.name,
      minutes,
      at: now,
    };
    await this.redis.client
      .multi()
      .lpush(FEED_KEY, JSON.stringify(item))
      .ltrim(FEED_KEY, 0, FEED_LENGTH - 1)
      .exec();
  }
}
