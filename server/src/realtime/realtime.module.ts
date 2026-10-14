import { Module } from '@nestjs/common';
import { AccountModule } from '../account/account.module.js';
import { AuthModule } from '../auth/auth.module.js';
import { CategoriesModule } from '../categories/categories.module.js';
import { LibraryModule } from '../library/library.module.js';
import { StatsModule } from '../stats/stats.module.js';
import { LibraryGateway } from './library.gateway.js';

@Module({
  imports: [
    AuthModule,
    AccountModule,
    LibraryModule,
    CategoriesModule,
    StatsModule,
  ],
  providers: [LibraryGateway],
})
export class RealtimeModule {}
