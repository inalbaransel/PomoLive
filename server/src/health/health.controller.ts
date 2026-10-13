import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { RedisService } from '../infra/redis.service.js';

/** Liveness/readiness probe for Coolify. The product API itself is WebSocket-only. */
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @Get()
  async check(): Promise<{ status: 'ok' }> {
    try {
      await Promise.all([this.prisma.$queryRaw`SELECT 1`, this.redis.client.ping()]);
      return { status: 'ok' };
    } catch {
      throw new ServiceUnavailableException();
    }
  }
}
