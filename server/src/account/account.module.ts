import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { LibraryModule } from '../library/library.module.js';
import { UsersModule } from '../users/users.module.js';
import { AccountService } from './account.service.js';

@Module({
  imports: [AuthModule, LibraryModule, UsersModule],
  providers: [AccountService],
  exports: [AccountService],
})
export class AccountModule {}
