import { Module } from '@nestjs/common';
import { ConfigModule } from './config/config.module.js';
import { HealthController } from './health/health.controller.js';
import { InfraModule } from './infra/infra.module.js';
import { RealtimeModule } from './realtime/realtime.module.js';

@Module({
  imports: [ConfigModule, InfraModule, RealtimeModule],
  controllers: [HealthController],
})
export class AppModule {}
