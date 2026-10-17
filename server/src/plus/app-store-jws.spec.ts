import { execFileSync } from 'node:child_process';
import { createPrivateKey, sign, X509Certificate } from 'node:crypto';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { verifySignedTransaction } from './app-store-jws.js';

/** A root → intermediate → leaf chain made with openssl, standing in for Apple's. */
function makeChain() {
  const dir = mkdtempSync(join(tmpdir(), 'jws-'));
  const run = (...args: string[]) =>
    execFileSync('openssl', args, { cwd: dir, stdio: 'pipe' });
  const key = (name: string) =>
    run(
      'ecparam',
      '-name',
      'prime256v1',
      '-genkey',
      '-noout',
      '-out',
      `${name}.key`,
    );
  writeFileSync(
    join(dir, 'ca.ext'),
    'basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign\n',
  );
  key('root');
  run(
    'req',
    '-x509',
    '-new',
    '-key',
    'root.key',
    '-subj',
    '/CN=Test Root',
    '-days',
    '30',
    '-out',
    'root.pem',
  );
  for (const [name, issuer, ext] of [
    ['inter', 'root', true],
    ['leaf', 'inter', false],
  ] as const) {
    key(name);
    run(
      'req',
      '-new',
      '-key',
      `${name}.key`,
      '-subj',
      `/CN=${name}`,
      '-out',
      `${name}.csr`,
    );
    run(
      'x509',
      '-req',
      '-in',
      `${name}.csr`,
      '-CA',
      `${issuer}.pem`,
      '-CAkey',
      `${issuer}.key`,
      '-CAcreateserial',
      '-days',
      '30',
      '-out',
      `${name}.pem`,
      ...(ext ? ['-extfile', 'ca.ext'] : []),
    );
  }
  const der = (name: string) =>
    new X509Certificate(readFileSync(join(dir, `${name}.pem`))).raw.toString(
      'base64',
    );
  return {
    x5c: [der('leaf'), der('inter'), der('root')],
    leafKey: createPrivateKey(readFileSync(join(dir, 'leaf.key'))),
    rootFingerprint: new X509Certificate(readFileSync(join(dir, 'root.pem')))
      .fingerprint256,
  };
}

describe('verifySignedTransaction', () => {
  const chain = makeChain();
  const now = Date.now();
  const options = {
    bundleId: 'com.baransel.pomolive',
    rootFingerprint: chain.rootFingerprint,
    allowsXcode: false,
    now,
  };
  const payload = {
    originalTransactionId: '2000000123',
    transactionId: '2000000456',
    bundleId: 'com.baransel.pomolive',
    productId: 'com.baransel.pomolive.plus.yearly',
    expiresDate: now + 86_400_000,
    environment: 'Sandbox',
  };

  const jws = (body: object, x5c = chain.x5c) => {
    const encode = (part: object) =>
      Buffer.from(JSON.stringify(part)).toString('base64url');
    const input = `${encode({ alg: 'ES256', x5c })}.${encode(body)}`;
    const signature = sign('sha256', Buffer.from(input), {
      key: chain.leafKey,
      dsaEncoding: 'ieee-p1363',
    });
    return `${input}.${signature.toString('base64url')}`;
  };

  it('accepts a transaction signed through the pinned root', () => {
    expect(verifySignedTransaction(jws(payload), options)).toMatchObject({
      originalTransactionId: '2000000123',
      productId: 'com.baransel.pomolive.plus.yearly',
    });
  });

  it('rejects another root, a tampered payload, another app and Xcode transactions', () => {
    expect(() =>
      verifySignedTransaction(jws(payload), {
        ...options,
        rootFingerprint: 'AA:BB',
      }),
    ).toThrow('Untrusted root');
    const [header, , signature] = jws(payload).split('.');
    const forged = Buffer.from(
      JSON.stringify({ ...payload, expiresDate: now + 9e12 }),
    ).toString('base64url');
    expect(() =>
      verifySignedTransaction(`${header}.${forged}.${signature}`, options),
    ).toThrow('Bad signature');
    expect(() =>
      verifySignedTransaction(
        jws({ ...payload, bundleId: 'com.other' }),
        options,
      ),
    ).toThrow('Wrong bundle');
    expect(() =>
      verifySignedTransaction(
        jws({ ...payload, environment: 'Xcode' }),
        options,
      ),
    ).toThrow('Xcode');
    expect(() =>
      verifySignedTransaction(
        jws(payload, [chain.x5c[0], chain.x5c[0], chain.x5c[2]]),
        options,
      ),
    ).toThrow('Broken');
  });
});
