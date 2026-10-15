import { Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { AppConfig } from '../config/app-config.js';
import { RedisService } from '../infra/redis.service.js';
import { LIBRARY_LAYOUT } from './layout/library-layout.js';
import { RoomKind, RoomState } from './library.types.js';
import { RedisKeys } from './redis-keys.js';

const PRESENCE_TTL_MS = 2 * 60_000;
const HALL_GLYPH = { symbol: 'building.columns.fill', color: 'brown' };

export interface RoomIdentity {
  id: string;
  kind: RoomKind;
  name: string;
  symbol: string;
  color: string;
  theme: string;
  description: string | null;
  code: string | null;
  ownerId: string | null;
}

export interface LiveCounts {
  presenceCount: number;
  occupiedCount: number;
}

/**
 * Live state of every room in Redis: who is looking at it and how many desks are taken.
 * System halls are created here and auto-sharded; user rooms get live state on first entry.
 */
@Injectable()
export class RoomDirectory {
  private readonly redis: Redis;

  constructor(
    redis: RedisService,
    private readonly config: AppConfig,
  ) {
    this.redis = redis.client;
  }

  static isHallId(roomId: string): boolean {
    return /^pixel-hall-\d+$/.test(roomId);
  }

  static hallIdentity(roomId: string): RoomIdentity {
    const number = roomId.slice('pixel-hall-'.length);
    return {
      id: roomId,
      kind: 'HALL',
      name: `Piksel Salon ${number}`,
      ...HALL_GLYPH,
      theme: 'classic',
      description: null,
      code: null,
      ownerId: null,
    };
  }

  /** All system halls, opening the first one if none exists yet. */
  async hallIds(): Promise<string[]> {
    const ids = await this.redis.zrange(RedisKeys.halls, '0', '-1');
    return ids.length > 0 ? ids : [await this.createHall()];
  }

  /** The first hall below the shard threshold, opening a new one when all are busy. */
  async assignHall(now: number): Promise<string> {
    const ids = await this.hallIds();
    const counts = await this.liveCounts(ids, now);
    return (
      ids.find(
        (id) => counts.get(id)!.presenceCount < this.config.shardThreshold,
      ) ?? this.createHall()
    );
  }

  /** Creates the room's live state unless it already exists, and marks user rooms as active. */
  async ensureLive(room: RoomIdentity, now: number): Promise<void> {
    if (await this.redis.hsetnx(RedisKeys.roomState(room.id), 'id', room.id)) {
      await this.redis.hset(RedisKeys.roomState(room.id), {
        kind: room.kind,
        name: room.name,
        symbol: room.symbol,
        color: room.color,
        theme: room.theme || 'classic',
        description: room.description ?? '',
        code: room.code ?? '',
        ownerId: room.ownerId ?? '',
      });
    }
    if (room.kind !== 'HALL')
      await this.redis.zadd(RedisKeys.liveRooms, now, room.id);
  }

  /** Rewrites a live room's name, icon and kind after the owner edited it. No-op if it is not live. */
  async updateIdentity(room: RoomIdentity): Promise<void> {
    if (!(await this.exists(room.id))) return;
    await this.redis.hset(RedisKeys.roomState(room.id), {
      kind: room.kind,
      name: room.name,
      symbol: room.symbol,
      color: room.color,
      theme: room.theme || 'classic',
      description: room.description ?? '',
    });
  }

  /** Readers looking at the room right now. */
  presentUserIds(roomId: string, now: number): Promise<string[]> {
    return this.redis.zrangebyscore(
      RedisKeys.roomPresence(roomId),
      now - PRESENCE_TTL_MS,
      '+inf',
    );
  }

  async exists(roomId: string): Promise<boolean> {
    return (await this.redis.exists(RedisKeys.roomState(roomId))) === 1;
  }

  async roomState(roomId: string, now: number): Promise<RoomState | null> {
    const fields = await this.redis.hgetall(RedisKeys.roomState(roomId));
    if (!fields.id) return null;
    const counts = (await this.liveCounts([roomId], now)).get(roomId)!;
    return {
      id: fields.id,
      kind: fields.kind as RoomKind,
      name: fields.name,
      symbol: fields.symbol,
      color: fields.color,
      theme: fields.theme || 'classic',
      description: fields.description || null,
      code: fields.code || null,
      ownerId: fields.ownerId || null,
      capacity: LIBRARY_LAYOUT.desks.length,
      ...counts,
    };
  }

  /** Readers looking at and seated in each room, in one round-trip. Rooms without live state count as empty. */
  async liveCounts(
    roomIds: string[],
    now: number,
  ): Promise<Map<string, LiveCounts>> {
    const pipeline = this.redis.pipeline();
    for (const roomId of roomIds) {
      pipeline.zcount(
        RedisKeys.roomPresence(roomId),
        now - PRESENCE_TTL_MS,
        '+inf',
      );
      pipeline.hlen(RedisKeys.roomDesks(roomId));
    }
    const results = (await pipeline.exec()) ?? [];
    return new Map(
      roomIds.map((roomId, index) => [
        roomId,
        {
          presenceCount: Number(results[index * 2]?.[1] ?? 0),
          occupiedCount: Number(results[index * 2 + 1]?.[1] ?? 0),
        },
      ]),
    );
  }

  async touchPresence(
    roomId: string,
    userId: string,
    now: number,
  ): Promise<void> {
    await this.redis.zadd(RedisKeys.roomPresence(roomId), now, userId);
    if (!RoomDirectory.isHallId(roomId))
      await this.redis.zadd(RedisKeys.liveRooms, now, roomId);
  }

  async removePresence(roomId: string, userId: string): Promise<void> {
    await this.redis.zrem(RedisKeys.roomPresence(roomId), userId);
  }

  /** Drops a room's live state entirely (it was deleted). Desks must be vacated first. */
  async close(roomId: string): Promise<void> {
    await this.redis
      .multi()
      .del(
        RedisKeys.roomState(roomId),
        RedisKeys.roomDesks(roomId),
        RedisKeys.roomPresence(roomId),
      )
      .zrem(RedisKeys.liveRooms, roomId)
      .exec();
  }

  /** Drops stale presence; deletes empty extra halls and the live state of empty user rooms. The first hall stays. */
  async collectGarbage(now: number): Promise<void> {
    const halls = await this.redis.zrange(RedisKeys.halls, '0', '-1');
    const liveRooms = await this.redis.zrange(RedisKeys.liveRooms, '0', '-1');
    for (const roomId of [...halls, ...liveRooms]) {
      await this.redis.zremrangebyscore(
        RedisKeys.roomPresence(roomId),
        '-inf',
        now - PRESENCE_TTL_MS,
      );
    }
    for (const roomId of halls.slice(1))
      await this.deleteIfEmpty(roomId, RedisKeys.halls);
    for (const roomId of liveRooms)
      await this.deleteIfEmpty(roomId, RedisKeys.liveRooms);
  }

  private async createHall(): Promise<string> {
    const sequence = await this.redis.incr(RedisKeys.hallSequence);
    const roomId = `pixel-hall-${sequence}`;
    await this.ensureLive(RoomDirectory.hallIdentity(roomId), Date.now());
    await this.redis.zadd(RedisKeys.halls, sequence, roomId);
    return roomId;
  }

  private async deleteIfEmpty(roomId: string, registry: string): Promise<void> {
    await this.redis.eval(
      `if redis.call('HLEN', KEYS[2]) == 0 and redis.call('ZCARD', KEYS[3]) == 0 then
         redis.call('DEL', KEYS[1], KEYS[2], KEYS[3])
         redis.call('ZREM', KEYS[4], ARGV[1])
       end`,
      4,
      RedisKeys.roomState(roomId),
      RedisKeys.roomDesks(roomId),
      RedisKeys.roomPresence(roomId),
      registry,
      roomId,
    );
  }
}
