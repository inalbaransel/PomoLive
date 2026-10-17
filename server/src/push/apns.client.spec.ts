import { generateKeyPairSync, verify } from 'node:crypto';
import { AppConfig } from '../config/app-config.js';
import { ApnsClient } from './apns.client.js';

describe('ApnsClient', () => {
  const { privateKey, publicKey } = generateKeyPairSync('ec', {
    namedCurve: 'P-256',
  });
  const pem = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();

  const client = (apns: AppConfig['apns']) =>
    new ApnsClient(Object.assign(new AppConfig(), { apns }));

  it('stays off without credentials', async () => {
    const disabled = client(null);
    expect(disabled.isEnabled).toBe(false);
    expect(
      await disabled.send('ab'.repeat(32), 'SANDBOX', { payload: {} }),
    ).toBe('failed');
  });

  it('signs an ES256 provider token Apple can verify, and reuses it', () => {
    const apns = client({
      keyId: 'ABC123DEFG',
      teamId: 'TEAM123456',
      privateKey: pem,
      bundleId: 'com.baransel.pomolive',
    });
    const jwt = (apns as unknown as { jwt(): string }).jwt();
    const [header, claims, signature] = jwt.split('.');
    expect(JSON.parse(Buffer.from(header, 'base64url').toString())).toEqual({
      alg: 'ES256',
      kid: 'ABC123DEFG',
    });
    expect(
      JSON.parse(Buffer.from(claims, 'base64url').toString()),
    ).toMatchObject({ iss: 'TEAM123456' });
    expect(
      verify(
        'sha256',
        Buffer.from(`${header}.${claims}`),
        { key: publicKey, dsaEncoding: 'ieee-p1363' },
        Buffer.from(signature, 'base64url'),
      ),
    ).toBe(true);
    expect((apns as unknown as { jwt(): string }).jwt()).toBe(jwt);
  });
});
