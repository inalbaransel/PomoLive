import { createHash } from 'node:crypto';
import { type JWTVerifyGetKey, jwtVerify } from 'jose';

export interface VerifiedIdentity {
  subject: string;
  /** Present only when the provider vouches that the address is verified. */
  email?: string;
  givenName?: string;
}

/**
 * Verifies an OpenID Connect ID token (Apple, Google) including the replay-protection nonce:
 * the client sends `sha256(rawNonce)` to the provider and `rawNonce` to us.
 */
export async function verifyIdToken(
  token: string,
  rawNonce: string,
  options: {
    keys: JWTVerifyGetKey;
    issuer: string | string[];
    audience: string | string[];
  },
): Promise<VerifiedIdentity> {
  const { payload } = await jwtVerify(token, options.keys, {
    issuer: options.issuer,
    audience: options.audience,
  });
  const expectedNonce = createHash('sha256').update(rawNonce).digest('hex');
  if (payload['nonce'] !== expectedNonce || !payload.sub) {
    throw new Error('ID token nonce mismatch');
  }
  const emailVerified =
    payload['email_verified'] === true || payload['email_verified'] === 'true';
  const email =
    typeof payload['email'] === 'string' && emailVerified
      ? payload['email']
      : undefined;
  const givenName =
    typeof payload['given_name'] === 'string'
      ? payload['given_name']
      : undefined;
  return { subject: payload.sub, email, givenName };
}
