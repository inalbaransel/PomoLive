import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { AppConfig } from '../config/app-config.js';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS = createRemoteJWKSet(new URL(`${APPLE_ISSUER}/auth/keys`));

/** Verifies Sign in with Apple identity tokens, including the replay-protection nonce. */
@Injectable()
export class AppleIdentityVerifier {
  constructor(private readonly config: AppConfig) {}

  async verify(identityToken: string, rawNonce: string): Promise<{ subject: string }> {
    const { payload } = await jwtVerify(identityToken, APPLE_KEYS, {
      issuer: APPLE_ISSUER,
      audience: this.config.appleBundleId,
    });
    const expectedNonce = createHash('sha256').update(rawNonce).digest('hex');
    if (payload['nonce'] !== expectedNonce || !payload.sub) {
      throw new Error('Apple identity token nonce mismatch');
    }
    return { subject: payload.sub };
  }
}
