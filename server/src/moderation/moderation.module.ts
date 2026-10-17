import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { ModerationService } from './moderation.service.js';

@Module({
  imports: [LibraryModule],
  providers: [ModerationService],
  exports: [ModerationService],
})
export class ModerationModule {}
