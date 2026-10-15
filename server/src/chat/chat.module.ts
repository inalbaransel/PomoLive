import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { ChatService } from './chat.service.js';

@Module({
  imports: [LibraryModule],
  providers: [ChatService],
  exports: [ChatService],
})
export class ChatModule {}
