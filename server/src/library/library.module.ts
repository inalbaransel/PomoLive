import { Module } from '@nestjs/common';
import { CategoriesModule } from '../categories/categories.module.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { RoomsRepository } from '../rooms/rooms.repository.js';
import { RoomActivityRepository } from '../rooms/room-activity.js';
import { RoomsService } from '../rooms/rooms.service.js';
import { RoomEventsService } from '../rooms/room-events.service.js';
import { UsersModule } from '../users/users.module.js';
import { DeskStore } from './desk-store.js';
import { FocusSessionsRepository } from './focus-sessions.repository.js';
import { LeaseReaper } from './lease-reaper.service.js';
import { LibraryService } from './library.service.js';
import { RoomDirectory } from './room-directory.js';

@Module({
  imports: [UsersModule, CategoriesModule],
  providers: [
    LibraryService,
    RoomDirectory,
    DeskStore,
    FocusSessionsRepository,
    LeaseReaper,
    RoomEventBus,
    RoomsRepository,
    RoomsService,
    RoomActivityRepository,
    RoomEventsService,
  ],
  exports: [
    LibraryService,
    RoomsService,
    RoomEventBus,
    RoomDirectory,
    DeskStore,
    FocusSessionsRepository,
    RoomsRepository,
    RoomEventsService,
  ],
})
export class LibraryModule {}
