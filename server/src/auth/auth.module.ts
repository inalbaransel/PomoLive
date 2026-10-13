import { Module } from '@nestjs/common';
import { MailModule } from '../mail/mail.module.js';
import { UsersModule } from '../users/users.module.js';
import { AppleIdentityVerifier } from './apple-identity.verifier.js';
import { AuthService } from './auth.service.js';
import { EmailCodes } from './email-codes.js';
import { GoogleIdentityVerifier } from './google-identity.verifier.js';
import { SessionTokens } from './session-tokens.js';

@Module({
  imports: [UsersModule, MailModule],
  providers: [
    AuthService,
    AppleIdentityVerifier,
    GoogleIdentityVerifier,
    EmailCodes,
    SessionTokens,
  ],
  exports: [AuthService],
})
export class AuthModule {}
