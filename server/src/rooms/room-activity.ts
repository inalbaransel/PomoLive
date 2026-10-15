import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { PrismaService } from '../infra/prisma.service.js';
import { RedisService } from '../infra/redis.service.js';
import { decay } from './discover-score.js';

const WEEK_MS = 7 * 24 * 60 * 60_000;
const CACHE_KEY = 'discover:activity';
const CACHE_SECONDS = 60;

/** What happened in a room over the last week. */
export interface RoomActivity {
  weeklyFocusMs: number;
  weeklyReaders: number;
  decayedFocusHours: number;
  /** The category with the most focus time, shown as the room's topic. */
  topic: CategoryInfo | null;
}

/**
 * Last-week activity of rooms, from recorded sessions. Computed for all rooms at once and cached
 * in Redis for a minute, so browsing Keşfet never runs the aggregation per request.
 */
@Injectable()
export class RoomActivityRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  async forRooms(
    roomIds: string[],
    now: number,
  ): Promise<Map<string, RoomActivity>> {
    const cached = await this.redis.client.get(CACHE_KEY);
    const all: Record<string, RoomActivity> = cached
      ? JSON.parse(cached)
      : await this.compute(now);
    return new Map(roomIds.filter((id) => all[id]).map((id) => [id, all[id]]));
  }

  private async compute(now: number): Promise<Record<string, RoomActivity>> {
    const sessions = await this.prisma.focusSession.findMany({
      where: { startedAt: { gte: new Date(now - WEEK_MS) } },
      select: {
        roomId: true,
        userId: true,
        startedAt: true,
        focusedMs: true,
        categoryKey: true,
        categoryName: true,
        categorySymbol: true,
        categoryColor: true,
      },
    });

    const rooms = new Map<
      string,
      {
        focusMs: number;
        decayedMs: number;
        readers: Set<string>;
        categories: Map<string, CategoryInfo & { ms: number }>;
      }
    >();
    for (const session of sessions) {
      const room = rooms.get(session.roomId) ?? {
        focusMs: 0,
        decayedMs: 0,
        readers: new Set(),
        categories: new Map(),
      };
      rooms.set(session.roomId, room);
      room.focusMs += session.focusedMs;
      room.decayedMs +=
        session.focusedMs * decay(now - session.startedAt.getTime());
      room.readers.add(session.userId);
      const category = room.categories.get(session.categoryKey) ?? {
        key: session.categoryKey,
        name: session.categoryName,
        symbol: session.categorySymbol,
        color: session.categoryColor,
        ms: 0,
      };
      category.ms += session.focusedMs;
      room.categories.set(session.categoryKey, category);
    }

    const result: Record<string, RoomActivity> = {};
    for (const [roomId, room] of rooms) {
      const top = [...room.categories.values()].sort((a, b) => b.ms - a.ms)[0];
      result[roomId] = {
        weeklyFocusMs: room.focusMs,
        weeklyReaders: room.readers.size,
        decayedFocusHours: room.decayedMs / 3_600_000,
        topic: top
          ? {
              key: top.key,
              name: top.name,
              symbol: top.symbol,
              color: top.color,
            }
          : null,
      };
    }
    await this.redis.client.set(
      CACHE_KEY,
      JSON.stringify(result),
      'EX',
      CACHE_SECONDS,
    );
    return result;
  }
}
