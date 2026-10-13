import { Injectable } from '@nestjs/common';
import { createRemoteJWKSet } from 'jose';
import { AppConfig } from '../config/app-config.js';
import { VerifiedIdentity, verifyIdToken } from './oidc.js';

const GOOGLE_KEYS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/oauth2/v3/certs'),
);

@Injectable()
export class GoogleIdentityVerifier {
  constructor(private readonly config: AppConfig) {}

  get isEnabled(): boolean {
    return this.config.googleClientIds.length > 0;
  }

  verify(idToken: string, rawNonce: string): Promise<VerifiedIdentity> {
    return verifyIdToken(idToken, rawNonce, {
      keys: GOOGLE_KEYS,
      issuer: ['https://accounts.google.com', 'accounts.google.com'],
      audience: this.config.googleClientIds,
    });
  }
}
