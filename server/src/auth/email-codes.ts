import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config.js';
import { RedisService } from '../infra/redis.service.js';
import { Mailer } from '../mail/mailer.js';
import { ProtocolError } from '../realtime/protocol-error.js';

const CODE_TTL_SECONDS = 10 * 60;
const RESEND_COOLDOWN_SECONDS = 60;
const MAX_ATTEMPTS = 5;

const codeKey = (email: string) => `auth:email:${email}:code`;
const cooldownKey = (email: string) => `auth:email:${email}:cooldown`;

/** Passwordless e-mail sign-in: a 6-digit code, stored only as an HMAC, valid for 10 minutes and 5 tries. */
@Injectable()
export class EmailCodes {
  constructor(
    private readonly config: AppConfig,
    private readonly redis: RedisService,
    private readonly mailer: Mailer,
  ) {}

  async send(email: string): Promise<{ resendAfterSeconds: number }> {
    const allowed = await this.redis.client.set(
      cooldownKey(email),
      '1',
      'EX',
      RESEND_COOLDOWN_SECONDS,
      'NX',
    );
    if (!allowed)
      ProtocolError.throw(
        'RATE_LIMITED',
        'Wait a minute before requesting another code',
      );

    const code = randomInt(0, 1_000_000).toString().padStart(6, '0');
    await this.redis.client
      .multi()
      .hset(codeKey(email), { digest: this.digest(email, code), attempts: 0 })
      .expire(codeKey(email), CODE_TTL_SECONDS)
      .exec();
    await this.mailer.sendSignInCode(email, code);
    return { resendAfterSeconds: RESEND_COOLDOWN_SECONDS };
  }

  /** Consumes the code on success; burns it after too many wrong guesses. */
  async verify(email: string, code: string): Promise<void> {
    const stored = await this.redis.client.hget(codeKey(email), 'digest');
    if (!stored)
      ProtocolError.throw('INVALID_CODE', 'Code expired, request a new one');

    const matches = timingSafeEqual(
      Buffer.from(stored, 'hex'),
      Buffer.from(this.digest(email, code), 'hex'),
    );
    if (matches) {
      await this.redis.client.del(codeKey(email));
      return;
    }
    const attempts = await this.redis.client.hincrby(
      codeKey(email),
      'attempts',
      1,
    );
    if (attempts >= MAX_ATTEMPTS) await this.redis.client.del(codeKey(email));
    ProtocolError.throw('INVALID_CODE', 'Wrong code');
  }

  private digest(email: string, code: string): string {
    return createHmac('sha256', this.config.sessionSecret)
      .update(`${email}:${code}`)
      .digest('hex');
  }
}
