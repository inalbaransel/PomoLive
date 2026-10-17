import { Module } from '@nestjs/common';
import { AccountModule } from '../account/account.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import { ChatModule } from '../chat/chat.module.js';
import { CommunityModule } from '../community/community.module.js';
import { LibraryModule } from '../library/library.module.js';
import { ModerationModule } from '../moderation/moderation.module.js';
import { PushModule } from '../push/push.module.js';
import { StatsModule } from '../stats/stats.module.js';
import { TasksModule } from '../tasks/tasks.module.js';
import { UsersModule } from '../users/users.module.js';
import { LibraryGateway } from './library.gateway.js';

@Module({
  imports: [
    AuthModule,
    AccountModule,
    LibraryModule,
    ModerationModule,
    PushModule,
    CategoriesModule,
    ChatModule,
    CommunityModule,
    StatsModule,
    TasksModule,
    UsersModule,
  ],
  providers: [LibraryGateway],
})
export class RealtimeModule {}
