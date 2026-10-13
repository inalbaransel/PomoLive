import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { Redis } from 'ioredis';
import { AppConfig } from '../config/app-config.js';

/**
 * Owns the two Redis connections the server needs: one for commands and Lua scripts,
 * and a dedicated one for pub/sub (a subscribed connection cannot issue other commands).
 */
@Injectable()
export class RedisService implements OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  readonly client: Redis;
  readonly subscriber: Redis;

  constructor(config: AppConfig) {
    this.client = new Redis(config.redisUrl, { maxRetriesPerRequest: 3 });
    this.subscriber = this.client.duplicate();
    for (const connection of [this.client, this.subscriber]) {
      connection.on('error', (error) => this.logger.error(error.message));
    }
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all([this.client.quit(), this.subscriber.quit()]);
  }
}
