import { Injectable, Logger, OnApplicationShutdown, OnModuleInit } from '@nestjs/common';
import { RedisService } from '../infra/redis.service.js';
import { DeskStore } from './desk-store.js';
import { LibraryService } from './library.service.js';
import { RedisKeys } from './redis-keys.js';
import { RoomDirectory } from './room-directory.js';

const TICK_MS = 5_000;
const GARBAGE_COLLECTION_EVERY_TICKS = 12;
const BATCH_SIZE = 200;

/**
 * Frees desks whose lease ran out (app killed, phone offline) and cleans up idle halls.
 * A short Redis lock makes sure only one server instance does this per tick.
 */
@Injectable()
export class LeaseReaper implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger(LeaseReaper.name);
  private timer: NodeJS.Timeout | undefined;
  private ticks = 0;

  constructor(
    private readonly redis: RedisService,
    private readonly desks: DeskStore,
    private readonly rooms: RoomDirectory,
    private readonly library: LibraryService,
  ) {}

  onModuleInit(): void {
    this.timer = setInterval(() => {
      this.tick().catch((error: Error) => this.logger.error(error.message));
    }, TICK_MS);
  }

  onApplicationShutdown(): void {
    clearInterval(this.timer);
  }

  private async tick(): Promise<void> {
    const acquired = await this.redis.client.set(RedisKeys.reaperLock, '1', 'PX', TICK_MS - 500, 'NX');
    if (!acquired) return;

    const now = Date.now();
    for (const lease of await this.desks.expiredLeases(now, BATCH_SIZE)) {
      await this.library.expireLease(lease, now);
    }
    if (++this.ticks % GARBAGE_COLLECTION_EVERY_TICKS === 0) await this.rooms.collectGarbage(now);
  }
}
