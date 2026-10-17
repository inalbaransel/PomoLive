import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { RedisService } from '../infra/redis.service.js';
import { PublicUser } from '../users/user.js';
import { ApnsClient, PushEnvironment } from './apns.client.js';

/** How long a connection counts as online after its last sign of life. */
const ONLINE_TTL_MS = 60_000;
/** At most one "started focusing" push per follower and person in this window. */
const FRIEND_PUSH_COOLDOWN_SECONDS = 30 * 60;
const MAX_DEVICES_PER_USER = 10;

const onlineKey = (userId: string) => `user:${userId}:online`;

/**
 * Reaches readers while the app is closed. Someone with a live connection already hears
 * everything over the socket, so pushes only go to readers who are offline.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
    private readonly apns: ApnsClient,
  ) {}

  async register(
    userId: string,
    token: string,
    environment: PushEnvironment,
  ): Promise<void> {
    // A token follows whoever signed in last on the device.
    await this.prisma.pushDevice.upsert({
      where: { token },
      update: { userId, environment },
      create: { token, userId, environment },
    });
    const stale = await this.prisma.pushDevice.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      skip: MAX_DEVICES_PER_USER,
      select: { token: true },
    });
    if (stale.length)
      await this.prisma.pushDevice.deleteMany({
        where: { token: { in: stale.map((device) => device.token) } },
      });
  }

  async unregister(userId: string, token: string): Promise<void> {
    await this.prisma.pushDevice.deleteMany({ where: { token, userId } });
  }

  // MARK: Presence

  /** Marks one connection alive; call again on every keep-alive. */
  async markOnline(userId: string, connectionId: string): Promise<void> {
    const now = Date.now();
    await this.redis.client
      .multi()
      .zadd(onlineKey(userId), now + ONLINE_TTL_MS, connectionId)
      .zremrangebyscore(onlineKey(userId), '-inf', now)
      .pexpire(onlineKey(userId), ONLINE_TTL_MS)
      .exec();
  }

  async markOffline(userId: string, connectionId: string): Promise<void> {
    await this.redis.client.zrem(onlineKey(userId), connectionId);
  }

  private async isOnline(userId: string): Promise<boolean> {
    return (
      (await this.redis.client.zcount(onlineKey(userId), Date.now(), '+inf')) >
      0
    );
  }

  // MARK: Notifications

  /** Tells offline followers that `user` sat down to focus. */
  async friendStarted(user: PublicUser): Promise<void> {
    if (!this.apns.isEnabled) return;
    const followers = await this.prisma.follow.findMany({
      where: { followeeId: user.id },
      select: { followerId: true },
    });
    const recipients: string[] = [];
    for (const { followerId } of followers) {
      if (await this.isOnline(followerId)) continue;
      const fresh = await this.redis.client.set(
        `push:friend:${followerId}:${user.id}`,
        '1',
        'EX',
        FRIEND_PUSH_COOLDOWN_SECONDS,
        'NX',
      );
      if (fresh) recipients.push(followerId);
    }
    if (!recipients.length) return;
    // Localised on the device from these keys, so each reader reads it in their own language.
    await this.deliver(recipients, {
      payload: {
        aps: {
          alert: {
            'title-loc-key': 'push.friendStarted.title',
            'title-loc-args': [user.displayName],
            'loc-key': 'push.friendStarted.body',
          },
          sound: 'default',
          'thread-id': 'friends',
        },
        kind: 'friendStarted',
        userId: user.id,
      },
      collapseId: `friend-${user.id}`,
    });
  }

  private async deliver(
    userIds: string[],
    notification: { payload: object; collapseId?: string },
  ): Promise<void> {
    const devices = await this.prisma.pushDevice.findMany({
      where: { userId: { in: userIds } },
      select: { token: true, environment: true },
    });
    const results = await Promise.all(
      devices.map(async (device) => ({
        token: device.token,
        result: await this.apns.send(
          device.token,
          device.environment,
          notification,
        ),
      })),
    );
    const gone = results
      .filter((entry) => entry.result === 'gone')
      .map((entry) => entry.token);
    if (gone.length) {
      await this.prisma.pushDevice.deleteMany({
        where: { token: { in: gone } },
      });
      this.logger.log(`Forgot ${gone.length} expired push tokens`);
    }
  }
}
