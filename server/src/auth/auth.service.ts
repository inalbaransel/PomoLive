import { Injectable } from '@nestjs/common';
import { RedisService } from '../infra/redis.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import type { AuthCommand } from '../realtime/protocol.js';
import { UserProfile } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';
import {
  DECOY_PASSWORD_HASH,
  hashPassword,
  verifyPassword,
} from './passwords.js';
import { IssuedSession, SessionTokens } from './session-tokens.js';

const MAX_FAILED_LOGINS = 10;
const FAILED_LOGIN_WINDOW_SECONDS = 15 * 60;

export interface AuthResult {
  user: UserProfile;
  session: IssuedSession;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly users: UsersRepository,
    private readonly sessions: SessionTokens,
    private readonly redis: RedisService,
  ) {}

  async authenticate(command: AuthCommand): Promise<AuthResult> {
    const user = await this.resolveUser(command);
    return { user, session: await this.sessions.issue(user.id) };
  }

  /** Re-checks the password before destructive account actions. */
  async confirmPassword(userId: string, password: string): Promise<void> {
    const hash = await this.users.passwordHash(userId);
    if (
      !(await verifyPassword(password, hash ?? DECOY_PASSWORD_HASH)) ||
      !hash
    ) {
      ProtocolError.throw('INVALID_CREDENTIALS', 'Password is wrong');
    }
  }

  private async resolveUser(command: AuthCommand): Promise<UserProfile> {
    switch (command.method) {
      case 'register':
        return this.users.create(
          command.email,
          await hashPassword(command.password),
          command.username,
          command.displayName,
        );
      case 'password':
        return this.logIn(command.login, command.password);
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

  /** Same error for an unknown login and a wrong password; repeated failures lock the login for a while. */
  private async logIn(login: string, password: string): Promise<UserProfile> {
    const failuresKey = `auth:failed-logins:${login}`;
    const failures = Number(await this.redis.client.get(failuresKey));
    if (failures >= MAX_FAILED_LOGINS)
      ProtocolError.throw('RATE_LIMITED', 'Too many attempts, try again later');

    const account = await this.users.findCredentials(login);
    const matches = await verifyPassword(
      password,
      account?.passwordHash ?? DECOY_PASSWORD_HASH,
    );
    if (!account || !matches) {
      await this.redis.client
        .multi()
        .incr(failuresKey)
        .expire(failuresKey, FAILED_LOGIN_WINDOW_SECONDS)
        .exec();
      ProtocolError.throw('INVALID_CREDENTIALS', 'Login or password is wrong');
    }

    await this.redis.client.del(failuresKey);
    const { passwordHash: _, ...profile } = account;
    return profile;
  }
}
