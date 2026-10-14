import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { AuthService } from './auth.service.js';
import { SessionTokens } from './session-tokens.js';

@Module({
  imports: [UsersModule],
  providers: [AuthService, SessionTokens],
  exports: [AuthService],
})
export class AuthModule {}
