import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { ModerationModule } from '../moderation/moderation.module.js';
import { ChatService } from './chat.service.js';

@Module({
  imports: [LibraryModule, ModerationModule],
  providers: [ChatService],
  exports: [ChatService],
})
export class ChatModule {}
