import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { RedisService } from '../infra/redis.service.js';
import { RedisKeys, roomIdFromEventsChannel } from '../library/redis-keys.js';

export interface Frame {
  event: string;
  data: object;
}

type RoomListener = (roomId: string, frame: Frame) => void;

/**
 * Fans room events out through Redis pub/sub so every server instance can push them
 * to its own sockets. Single-instance deployments pay one local round-trip for this.
 */
@Injectable()
export class RoomEventBus implements OnModuleInit {
  private readonly logger = new Logger(RoomEventBus.name);
  private readonly listeners = new Set<RoomListener>();

  constructor(private readonly redis: RedisService) {}

  async onModuleInit(): Promise<void> {
    this.redis.subscriber.on('pmessage', (_pattern, channel, message) => {
      const roomId = roomIdFromEventsChannel(channel);
      const frame = JSON.parse(message) as Frame;
      for (const listener of this.listeners) listener(roomId, frame);
    });
    await this.redis.subscriber.psubscribe(RedisKeys.roomEventsPattern);
  }

  async publish(roomId: string, event: string, data: object): Promise<void> {
    await this.redis.client
      .publish(RedisKeys.roomEvents(roomId), JSON.stringify({ event, data }))
      .catch((error: Error) => this.logger.error(`Publish to ${roomId} failed: ${error.message}`));
  }

  subscribe(listener: RoomListener): void {
    this.listeners.add(listener);
  }
}
