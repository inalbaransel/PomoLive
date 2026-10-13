import { Injectable } from '@nestjs/common';
import { createRemoteJWKSet } from 'jose';
import { AppConfig } from '../config/app-config.js';
import { VerifiedIdentity, verifyIdToken } from './oidc.js';

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS = createRemoteJWKSet(new URL(`${APPLE_ISSUER}/auth/keys`));

@Injectable()
export class AppleIdentityVerifier {
  constructor(private readonly config: AppConfig) {}

  verify(identityToken: string, rawNonce: string): Promise<VerifiedIdentity> {
    return verifyIdToken(identityToken, rawNonce, {
      keys: APPLE_KEYS,
      issuer: APPLE_ISSUER,
      audience: this.config.appleBundleId,
    });
  }
}
