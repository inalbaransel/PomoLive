import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto';

/** OWASP-recommended scrypt cost; ~50 ms per hash on a small VPS. */
const COST = { N: 2 ** 15, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
const KEY_LENGTH = 32;

function derive(
  password: string,
  salt: Buffer,
  cost: typeof COST,
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scrypt(password.normalize('NFKC'), salt, KEY_LENGTH, cost, (error, key) =>
      error ? reject(error) : resolve(key),
    );
  });
}

/** `scrypt$N$r$p$salt$key`, so the cost can be raised later without breaking existing hashes. */
export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const key = await derive(password, salt, COST);
  return [
    'scrypt',
    COST.N,
    COST.r,
    COST.p,
    salt.toString('base64'),
    key.toString('base64'),
  ].join('$');
}

export async function verifyPassword(
  password: string,
  stored: string,
): Promise<boolean> {
  const [algorithm, N, r, p, salt, key] = stored.split('$');
  if (algorithm !== 'scrypt' || !salt || !key) return false;
  const expected = Buffer.from(key, 'base64');
  const actual = await derive(password, Buffer.from(salt, 'base64'), {
    ...COST,
    N: Number(N),
    r: Number(r),
    p: Number(p),
  });
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/** Verified against when the e-mail is unknown, so response time does not reveal which accounts exist. */
export const DECOY_PASSWORD_HASH = await hashPassword(
  randomBytes(16).toString('hex'),
);
