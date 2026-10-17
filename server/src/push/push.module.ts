import { Module } from '@nestjs/common';
import { ApnsClient } from './apns.client.js';
import { PushService } from './push.service.js';

@Module({
  providers: [ApnsClient, PushService],
  exports: [PushService],
})
export class PushModule {}
