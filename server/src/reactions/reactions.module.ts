import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { ModerationModule } from '../moderation/moderation.module.js';
import { ReactionsService } from './reactions.service.js';

@Module({
  imports: [LibraryModule, ModerationModule],
  providers: [ReactionsService],
  exports: [ReactionsService],
})
export class ReactionsModule {}
