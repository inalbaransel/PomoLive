import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import type { AuthCommand } from '../realtime/protocol.js';
import { UserProfile } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';
import { AppleIdentityVerifier } from './apple-identity.verifier.js';
import { IssuedSession, SessionTokens } from './session-tokens.js';

export interface AuthResult {
  user: UserProfile;
  session: IssuedSession;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly config: AppConfig,
    private readonly apple: AppleIdentityVerifier,
    private readonly sessions: SessionTokens,
    private readonly users: UsersRepository,
  ) {}

  async authenticate(command: AuthCommand): Promise<AuthResult> {
    const user = await this.resolveUser(command);
    return { user, session: await this.sessions.issue(user.id) };
  }

  private async resolveUser(command: AuthCommand): Promise<UserProfile> {
    switch (command.method) {
      case 'apple': {
        const { subject } = await this.apple
          .verify(command.identityToken, command.rawNonce)
          .catch(() => ProtocolError.throw('UNAUTHORIZED', 'Apple identity token is invalid'));
        return this.users.upsertByIdentity({ kind: 'apple', subject }, command.displayName);
      }
      case 'session': {
        const userId = await this.sessions
          .verify(command.sessionToken)
          .catch(() => ProtocolError.throw('UNAUTHORIZED', 'Session expired'));
        return (await this.users.findById(userId)) ?? ProtocolError.throw('UNAUTHORIZED', 'Account no longer exists');
      }
      case 'dev': {
        if (!this.config.devAuthEnabled) ProtocolError.throw('UNAUTHORIZED', 'Developer sign-in is disabled');
        return this.users.upsertByIdentity({ kind: 'dev', subject: command.deviceId }, command.displayName);
      }
    }
  }
}
