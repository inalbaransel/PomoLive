import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { AppleIdentityVerifier } from './apple-identity.verifier.js';
import { AuthService } from './auth.service.js';
import { SessionTokens } from './session-tokens.js';

@Module({
  imports: [UsersModule],
  providers: [AuthService, AppleIdentityVerifier, SessionTokens],
  exports: [AuthService],
})
export class AuthModule {}
