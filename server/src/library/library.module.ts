import { Module } from '@nestjs/common';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { UsersModule } from '../users/users.module.js';
import { DeskStore } from './desk-store.js';
import { FocusSessionsRepository } from './focus-sessions.repository.js';
import { LeaseReaper } from './lease-reaper.service.js';
import { LibraryService } from './library.service.js';
import { RoomDirectory } from './room-directory.js';

@Module({
  imports: [UsersModule],
  providers: [
    LibraryService,
    RoomDirectory,
    DeskStore,
    FocusSessionsRepository,
    LeaseReaper,
    RoomEventBus,
  ],
  exports: [LibraryService, RoomEventBus],
})
export class LibraryModule {}
