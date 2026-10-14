import { Injectable } from '@nestjs/common';
import { jwtVerify, SignJWT } from 'jose';
import { AppConfig } from '../config/app-config.js';

const ISSUER = 'pomolive';
const LIFETIME_SECONDS = 60 * 60 * 24 * 30;

export interface IssuedSession {
  token: string;
  expiresAt: number;
}

/** Long-lived bearer tokens that let a device reconnect without asking for the password again. */
@Injectable()
export class SessionTokens {
  private readonly key: Uint8Array;

  constructor(config: AppConfig) {
    this.key = new TextEncoder().encode(config.sessionSecret);
  }

  async issue(userId: string): Promise<IssuedSession> {
    const expiresAt = Math.floor(Date.now() / 1000) + LIFETIME_SECONDS;
    const token = await new SignJWT()
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer(ISSUER)
      .setSubject(userId)
      .setIssuedAt()
      .setExpirationTime(expiresAt)
      .sign(this.key);
    return { token, expiresAt: expiresAt * 1000 };
  }

  async verify(token: string): Promise<string> {
    const { payload } = await jwtVerify(token, this.key, {
      issuer: ISSUER,
      algorithms: ['HS256'],
    });
    if (!payload.sub) throw new Error('Session token has no subject');
    return payload.sub;
  }
}
