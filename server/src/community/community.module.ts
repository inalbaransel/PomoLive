import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { StatsModule } from '../stats/stats.module.js';
import { UsersModule } from '../users/users.module.js';
import { ProfilesService } from './profiles.service.js';
import { RoomMembersService } from './room-members.service.js';

@Module({
  imports: [LibraryModule, StatsModule, UsersModule],
  providers: [RoomMembersService, ProfilesService],
  exports: [RoomMembersService, ProfilesService],
})
export class CommunityModule {}
