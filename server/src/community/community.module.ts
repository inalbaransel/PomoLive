import { Module } from '@nestjs/common';
import { LibraryModule } from '../library/library.module.js';
import { ModerationModule } from '../moderation/moderation.module.js';
import { StatsModule } from '../stats/stats.module.js';
import { UsersModule } from '../users/users.module.js';
import { ProfilesService } from './profiles.service.js';
import { RoomMembersService } from './room-members.service.js';
import { SocialService } from './social.service.js';

@Module({
  imports: [LibraryModule, ModerationModule, StatsModule, UsersModule],
  providers: [RoomMembersService, ProfilesService, SocialService],
  exports: [RoomMembersService, ProfilesService, SocialService],
})
export class CommunityModule {}
