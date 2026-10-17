import { createPublicKey, verify, X509Certificate } from 'node:crypto';

/** The fields of an App Store `JWSTransactionDecodedPayload` that PomoLive uses. */
export interface SignedTransaction {
  originalTransactionId: string;
  transactionId: string;
  bundleId: string;
  productId: string;
  /** ms epoch; subscriptions only. */
  expiresDate?: number;
  revocationDate?: number;
  environment: 'Production' | 'Sandbox' | 'Xcode';
}

export interface VerifyOptions {
  bundleId: string;
  /** SHA-256 fingerprint of the trusted root, upper-case hex pairs separated by colons. */
  rootFingerprint: string;
  allowsXcode: boolean;
  now: number;
}

export class InvalidTransactionError extends Error {}

/**
 * Verifies a StoreKit 2 signed transaction (`Transaction.jwsRepresentation`) without third-party
 * code: the x5c chain must lead, signature by signature, to the pinned Apple root, every
 * certificate must be within its validity, and the leaf must have signed the payload (ES256).
 * Transactions from Xcode's local StoreKit testing carry their own root and are accepted only
 * when explicitly allowed for development.
 */
export function verifySignedTransaction(
  jws: string,
  options: VerifyOptions,
): SignedTransaction {
  const parts = jws.split('.');
  if (parts.length !== 3) throw new InvalidTransactionError('Malformed JWS');
  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const header = decode<{ alg?: string; x5c?: string[] }>(encodedHeader);
  const payload = decode<SignedTransaction>(encodedPayload);
  if (header.alg !== 'ES256')
    throw new InvalidTransactionError('Unexpected algorithm');
  if (!header.x5c?.length)
    throw new InvalidTransactionError('Missing certificate chain');

  const chain = header.x5c.map(
    (der) => new X509Certificate(Buffer.from(der, 'base64')),
  );
  const isXcode = payload.environment === 'Xcode';
  if (isXcode && !options.allowsXcode)
    throw new InvalidTransactionError('Xcode transactions are not accepted');
  if (!isXcode) {
    if (chain.length !== 3)
      throw new InvalidTransactionError('Unexpected chain length');
    const root = chain[2];
    if (root.fingerprint256.toUpperCase() !== options.rootFingerprint)
      throw new InvalidTransactionError('Untrusted root certificate');
    for (let index = 0; index < chain.length; index++) {
      const certificate = chain[index];
      const issuer = chain[Math.min(index + 1, chain.length - 1)];
      if (!certificate.verify(issuer.publicKey))
        throw new InvalidTransactionError('Broken certificate chain');
      if (
        Date.parse(certificate.validFrom) > options.now ||
        Date.parse(certificate.validTo) < options.now
      )
        throw new InvalidTransactionError('Certificate outside its validity');
    }
  }

  const signed = verify(
    'sha256',
    Buffer.from(`${encodedHeader}.${encodedPayload}`),
    {
      key: createPublicKey(
        chain[0].publicKey.export({ format: 'pem', type: 'spki' }),
      ),
      dsaEncoding: 'ieee-p1363',
    },
    Buffer.from(encodedSignature, 'base64url'),
  );
  if (!signed) throw new InvalidTransactionError('Bad signature');
  if (payload.bundleId !== options.bundleId)
    throw new InvalidTransactionError('Wrong bundle');
  return payload;
}

function decode<T>(part: string): T {
  try {
    return JSON.parse(Buffer.from(part, 'base64url').toString('utf8')) as T;
  } catch {
    throw new InvalidTransactionError('Malformed JWS');
  }
}
