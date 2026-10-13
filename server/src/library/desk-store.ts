import { Injectable } from '@nestjs/common';
import type { Redis, Result } from 'ioredis';
import { RedisService } from '../infra/redis.service.js';
import { DeskRecord } from './library.types.js';
import { RedisKeys } from './redis-keys.js';

export type ClaimOutcome =
  'OK' | 'ROOM_NOT_FOUND' | 'DESK_TAKEN' | 'ALREADY_SEATED';

export interface SeatRef {
  roomId: string;
  deskId: string;
}

export interface LeaseRef extends SeatRef {
  userId: string;
}

declare module 'ioredis' {
  interface RedisCommander<Context> {
    claimDesk(
      ...args: [
        state: string,
        desks: string,
        seat: string,
        leases: string,
        deskId: string,
        record: string,
        seatValue: string,
        leaseMember: string,
        leaseExpiresAt: number,
      ]
    ): Result<ClaimOutcome, Context>;
    releaseDesk(
      ...args: [
        desks: string,
        seat: string,
        leases: string,
        deskId: string,
        userId: string,
        seatValue: string,
        leaseMember: string,
        expiredBefore: number,
      ]
    ): Result<string | null, Context>;
    patchDesk(
      ...args: [
        desks: string,
        leases: string,
        deskId: string,
        userId: string,
        patch: string,
        leaseMember: string,
      ]
    ): Result<string | null, Context>;
  }
}

/**
 * Every desk mutation is a Lua script so a desk, its owner's seat pointer and its lease
 * can never disagree, even with many server instances racing for the same chair.
 */
const SCRIPTS = {
  claimDesk: {
    numberOfKeys: 4,
    lua: `
      if redis.call('EXISTS', KEYS[1]) == 0 then return 'ROOM_NOT_FOUND' end
      if redis.call('HEXISTS', KEYS[2], ARGV[1]) == 1 then return 'DESK_TAKEN' end
      if redis.call('EXISTS', KEYS[3]) == 1 then return 'ALREADY_SEATED' end
      redis.call('HSET', KEYS[2], ARGV[1], ARGV[2])
      redis.call('SET', KEYS[3], ARGV[3])
      redis.call('ZADD', KEYS[4], ARGV[5], ARGV[4])
      return 'OK'`,
  },
  releaseDesk: {
    numberOfKeys: 3,
    lua: `
      local function dropPointers()
        redis.call('ZREM', KEYS[3], ARGV[4])
        if redis.call('GET', KEYS[2]) == ARGV[3] then redis.call('DEL', KEYS[2]) end
      end
      local raw = redis.call('HGET', KEYS[1], ARGV[1])
      if not raw then dropPointers() return false end
      local record = cjson.decode(raw)
      if record.userId ~= ARGV[2] then dropPointers() return false end
      local expiredBefore = tonumber(ARGV[5])
      if expiredBefore > 0 and record.leaseExpiresAt > expiredBefore then return false end
      redis.call('HDEL', KEYS[1], ARGV[1])
      dropPointers()
      return raw`,
  },
  patchDesk: {
    numberOfKeys: 2,
    lua: `
      local raw = redis.call('HGET', KEYS[1], ARGV[1])
      if not raw then return false end
      local record = cjson.decode(raw)
      if record.userId ~= ARGV[2] then return false end
      for key, value in pairs(cjson.decode(ARGV[3])) do record[key] = value end
      local encoded = cjson.encode(record)
      redis.call('HSET', KEYS[1], ARGV[1], encoded)
      redis.call('ZADD', KEYS[2], record.leaseExpiresAt, ARGV[4])
      return encoded`,
  },
} as const;

const leaseMember = ({ roomId, deskId, userId }: LeaseRef) =>
  `${roomId}|${deskId}|${userId}`;
const seatValue = ({ roomId, deskId }: SeatRef) => `${roomId}|${deskId}`;

@Injectable()
export class DeskStore {
  private readonly redis: Redis;

  constructor(redis: RedisService) {
    this.redis = redis.client;
    for (const [name, { numberOfKeys, lua }] of Object.entries(SCRIPTS)) {
      this.redis.defineCommand(name, { numberOfKeys, lua });
    }
  }

  claim(roomId: string, desk: DeskRecord): Promise<ClaimOutcome> {
    const ref = { roomId, deskId: desk.deskId, userId: desk.userId };
    return this.redis.claimDesk(
      RedisKeys.roomState(roomId),
      RedisKeys.roomDesks(roomId),
      RedisKeys.userSeat(desk.userId),
      RedisKeys.deskLeases,
      desk.deskId,
      JSON.stringify(desk),
      seatValue(ref),
      leaseMember(ref),
      desk.leaseExpiresAt,
    );
  }

  /** Frees the desk. With `expiredBefore`, only succeeds if the lease was not renewed meanwhile. */
  async release(ref: LeaseRef, expiredBefore = 0): Promise<DeskRecord | null> {
    const raw = await this.redis.releaseDesk(
      RedisKeys.roomDesks(ref.roomId),
      RedisKeys.userSeat(ref.userId),
      RedisKeys.deskLeases,
      ref.deskId,
      ref.userId,
      seatValue(ref),
      leaseMember(ref),
      expiredBefore,
    );
    return raw ? (JSON.parse(raw) as DeskRecord) : null;
  }

  async patch(
    ref: LeaseRef,
    changes: Partial<Omit<DeskRecord, 'deskId' | 'userId'>>,
  ): Promise<DeskRecord | null> {
    const raw = await this.redis.patchDesk(
      RedisKeys.roomDesks(ref.roomId),
      RedisKeys.deskLeases,
      ref.deskId,
      ref.userId,
      JSON.stringify(changes),
      leaseMember(ref),
    );
    return raw ? (JSON.parse(raw) as DeskRecord) : null;
  }

  async get(ref: SeatRef): Promise<DeskRecord | null> {
    const raw = await this.redis.hget(
      RedisKeys.roomDesks(ref.roomId),
      ref.deskId,
    );
    return raw ? (JSON.parse(raw) as DeskRecord) : null;
  }

  async list(roomId: string): Promise<DeskRecord[]> {
    const values = await this.redis.hvals(RedisKeys.roomDesks(roomId));
    return values.map((raw) => JSON.parse(raw) as DeskRecord);
  }

  async seatOf(userId: string): Promise<SeatRef | null> {
    const value = await this.redis.get(RedisKeys.userSeat(userId));
    if (!value) return null;
    const [roomId, deskId] = value.split('|');
    return { roomId, deskId };
  }

  async expiredLeases(now: number, limit: number): Promise<LeaseRef[]> {
    const members = await this.redis.zrangebyscore(
      RedisKeys.deskLeases,
      '-inf',
      now,
      'LIMIT',
      0,
      limit,
    );
    return members.map((member) => {
      const [roomId, deskId, userId] = member.split('|');
      return { roomId, deskId, userId };
    });
  }
}
