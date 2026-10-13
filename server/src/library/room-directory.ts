import { randomInt } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { AppConfig } from '../config/app-config.js';
import { RedisService } from '../infra/redis.service.js';
import { cyclePhaseAt } from './cycle.js';
import { LIBRARY_LAYOUT } from './layout/library-layout.js';
import { RoomState, RoomType } from './library.types.js';
import { RedisKeys } from './redis-keys.js';

const PRESENCE_TTL_MS = 2 * 60_000;
const PRIVATE_ROOM_IDLE_MS = 24 * 60 * 60_000;
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** Creates rooms, routes readers into public halls (auto-sharding) and tracks who is looking at which hall. */
@Injectable()
export class RoomDirectory {
  private readonly redis: Redis;

  constructor(
    redis: RedisService,
    private readonly config: AppConfig,
  ) {
    this.redis = redis.client;
  }

  /** The first public hall below the shard threshold, opening a new one when all are busy. */
  async assignPublicRoom(now: number): Promise<string> {
    const roomIds = await this.redis.zrange(RedisKeys.publicRooms, '0', '-1');
    const counts = await Promise.all(roomIds.map((roomId) => this.presenceCount(roomId, now)));
    const available = roomIds.find((_, index) => counts[index] < this.config.shardThreshold);
    return available ?? this.createPublicRoom(now);
  }

  async createPrivateRoom(now: number): Promise<{ roomId: string; code: string }> {
    for (;;) {
      const code = Array.from({ length: 6 }, () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)]).join('');
      const roomId = RoomDirectory.privateRoomId(code);
      if (await this.redis.hsetnx(RedisKeys.roomState(roomId), 'id', roomId)) {
        await this.writeRoomState(roomId, 'PRIVATE', code, now);
        await this.redis.zadd(RedisKeys.privateRooms, now, roomId);
        return { roomId, code };
      }
    }
  }

  async exists(roomId: string): Promise<boolean> {
    return (await this.redis.exists(RedisKeys.roomState(roomId))) === 1;
  }

  async roomState(roomId: string, now: number): Promise<RoomState | null> {
    const [[, fields], [, occupiedCount], [, presenceCount]] = (await this.redis
      .multi()
      .hgetall(RedisKeys.roomState(roomId))
      .hlen(RedisKeys.roomDesks(roomId))
      .zcount(RedisKeys.roomPresence(roomId), now - PRESENCE_TTL_MS, '+inf')
      .exec())! as [[null, Record<string, string>], [null, number], [null, number]];
    if (!fields.id) return null;

    const focusMinutes = Number(fields.focusMinutes);
    const breakMinutes = Number(fields.breakMinutes);
    const cycleAnchorAt = Number(fields.cycleAnchorAt);
    const cycle = cyclePhaseAt(cycleAnchorAt, focusMinutes, breakMinutes, now);
    return {
      id: fields.id,
      type: fields.type as RoomType,
      code: fields.code || null,
      capacity: LIBRARY_LAYOUT.desks.length,
      occupiedCount,
      presenceCount,
      focusMinutes,
      breakMinutes,
      cycleAnchorAt,
      cyclePhase: cycle.phase,
      cycleEndsAt: cycle.endsAt,
    };
  }

  async touchPresence(roomId: string, userId: string, now: number): Promise<void> {
    await this.redis.zadd(RedisKeys.roomPresence(roomId), now, userId);
    if (roomId.startsWith('private-')) await this.redis.zadd(RedisKeys.privateRooms, now, roomId);
  }

  async removePresence(roomId: string, userId: string): Promise<void> {
    await this.redis.zrem(RedisKeys.roomPresence(roomId), userId);
  }

  /** Drops stale presence and deletes halls nobody uses. The first public hall is permanent. */
  async collectGarbage(now: number): Promise<void> {
    const publicRooms = await this.redis.zrange(RedisKeys.publicRooms, '0', '-1');
    const privateRooms = await this.redis.zrange(RedisKeys.privateRooms, '0', '-1', 'WITHSCORES');

    for (const roomId of [...publicRooms, ...privateRooms.filter((_, index) => index % 2 === 0)]) {
      await this.redis.zremrangebyscore(RedisKeys.roomPresence(roomId), '-inf', now - PRESENCE_TTL_MS);
    }
    for (const roomId of publicRooms.slice(1)) {
      await this.deleteIfEmpty(roomId, RedisKeys.publicRooms);
    }
    for (let index = 0; index < privateRooms.length; index += 2) {
      const [roomId, lastActiveAt] = [privateRooms[index], Number(privateRooms[index + 1])];
      if (now - lastActiveAt > PRIVATE_ROOM_IDLE_MS) await this.deleteIfEmpty(roomId, RedisKeys.privateRooms);
    }
  }

  static privateRoomId(code: string): string {
    return `private-${code}`;
  }

  private async createPublicRoom(now: number): Promise<string> {
    const sequence = await this.redis.incr(RedisKeys.roomSequence);
    const roomId = `pixel-hall-${sequence}`;
    await this.writeRoomState(roomId, 'PUBLIC', '', now);
    await this.redis.zadd(RedisKeys.publicRooms, sequence, roomId);
    return roomId;
  }

  private async writeRoomState(roomId: string, type: RoomType, code: string, now: number): Promise<void> {
    await this.redis.hset(RedisKeys.roomState(roomId), {
      id: roomId,
      type,
      code,
      focusMinutes: this.config.focusMinutes,
      breakMinutes: this.config.breakMinutes,
      cycleAnchorAt: Math.floor(now / 60_000) * 60_000,
      createdAt: now,
    });
  }

  private async presenceCount(roomId: string, now: number): Promise<number> {
    return this.redis.zcount(RedisKeys.roomPresence(roomId), now - PRESENCE_TTL_MS, '+inf');
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
