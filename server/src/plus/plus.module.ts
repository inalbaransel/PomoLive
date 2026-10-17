import { Module } from '@nestjs/common';
import { PlusService } from './plus.service.js';

@Module({
  providers: [PlusService],
  exports: [PlusService],
})
export class PlusModule {}
