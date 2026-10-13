import { Injectable } from '@nestjs/common';
import { ProtocolError } from '../realtime/protocol-error.js';
import type { AuthCommand } from '../realtime/protocol.js';
import { UserProfile } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';
import { AppleIdentityVerifier } from './apple-identity.verifier.js';
import { EmailCodes } from './email-codes.js';
import { GoogleIdentityVerifier } from './google-identity.verifier.js';
import { VerifiedIdentity } from './oidc.js';
import { IssuedSession, SessionTokens } from './session-tokens.js';

export interface AuthResult {
  user: UserProfile;
  session: IssuedSession;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly apple: AppleIdentityVerifier,
    private readonly google: GoogleIdentityVerifier,
    private readonly emailCodes: EmailCodes,
    private readonly sessions: SessionTokens,
    private readonly users: UsersRepository,
  ) {}

  async authenticate(command: AuthCommand): Promise<AuthResult> {
    const user = await this.resolveUser(command);
    return { user, session: await this.sessions.issue(user.id) };
  }

  requestEmailCode(email: string): Promise<{ resendAfterSeconds: number }> {
    return this.emailCodes.send(email);
  }

  private async resolveUser(command: AuthCommand): Promise<UserProfile> {
    switch (command.method) {
      case 'apple': {
        const identity = await this.apple
          .verify(command.identityToken, command.rawNonce)
          .catch(() =>
            ProtocolError.throw(
              'UNAUTHORIZED',
              'Apple identity token is invalid',
            ),
          );
        return this.signIn('apple', identity, command.displayName);
      }
      case 'google': {
        if (!this.google.isEnabled)
          ProtocolError.throw(
            'UNAVAILABLE',
            'Google sign-in is not configured',
          );
        const identity = await this.google
          .verify(command.identityToken, command.rawNonce)
          .catch(() =>
            ProtocolError.throw(
              'UNAUTHORIZED',
              'Google identity token is invalid',
            ),
          );
        return this.signIn('google', identity, command.displayName);
      }
      case 'email': {
        await this.emailCodes.verify(command.email, command.code);
        return this.users.signIn({
          provider: 'email',
          subject: command.email,
          email: command.email,
          displayName: command.displayName,
        });
      }
      case 'session': {
        const userId = await this.sessions
          .verify(command.sessionToken)
          .catch(() => ProtocolError.throw('UNAUTHORIZED', 'Session expired'));
        return (
          (await this.users.findById(userId)) ??
          ProtocolError.throw('UNAUTHORIZED', 'Account no longer exists')
        );
      }
    }
  }

  private signIn(
    provider: 'apple' | 'google',
    identity: VerifiedIdentity,
    displayName: string | undefined,
  ) {
    return this.users.signIn({
      provider,
      subject: identity.subject,
      email: identity.email?.toLowerCase(),
      displayName: displayName ?? identity.givenName?.slice(0, 24),
    });
  }
}
