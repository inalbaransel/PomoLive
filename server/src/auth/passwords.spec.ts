import { hashPassword, verifyPassword } from './passwords.js';

describe('passwords', () => {
  it('verifies the original password and rejects others', async () => {
    const hash = await hashPassword('doğru-şifre-123');
    expect(hash).toMatch(/^scrypt\$32768\$8\$1\$/);
    expect(await verifyPassword('doğru-şifre-123', hash)).toBe(true);
    expect(await verifyPassword('yanlış-şifre-123', hash)).toBe(false);
  });

  it('salts every hash', async () => {
    expect(await hashPassword('aynı-şifre')).not.toBe(
      await hashPassword('aynı-şifre'),
    );
  });

  it('rejects malformed hashes', async () => {
    expect(await verifyPassword('x', 'not-a-hash')).toBe(false);
  });
});
