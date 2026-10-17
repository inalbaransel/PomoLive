import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { ModerationModule } from '../moderation/moderation.module.js';
import { MatchService } from './match.service.js';

@Module({
  imports: [LibraryModule, ModerationModule],
  providers: [MatchService],
  exports: [MatchService],
})
export class MatchModule {}
