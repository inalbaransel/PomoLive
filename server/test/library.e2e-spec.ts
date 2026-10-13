import { INestApplication } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'node:crypto';
import { AddressInfo } from 'node:net';
import { WebSocket } from 'ws';
import { AppModule } from '../src/app.module.js';
import { RedisService } from '../src/infra/redis.service.js';
import { RedisKeys } from '../src/library/redis-keys.js';
import { Mailer } from '../src/mail/mailer.js';

interface Frame {
  event: string;
  data: any;
}

/** Minimal client mirroring the iOS `LibrarySocket`: request/reply by `ref`, plus a broadcast inbox. */
class TestClient {
  private readonly inbox: Frame[] = [];
  private readonly waiters: Array<{
    match: (frame: Frame) => boolean;
    resolve: (frame: Frame) => void;
  }> = [];
  private nextRef = 0;

  private constructor(private readonly socket: WebSocket) {
    socket.on('message', (raw: Buffer) => {
      const frame = JSON.parse(raw.toString()) as Frame;
      const waiter = this.waiters.find((candidate) => candidate.match(frame));
      if (waiter) {
        this.waiters.splice(this.waiters.indexOf(waiter), 1);
        waiter.resolve(frame);
      } else {
        this.inbox.push(frame);
      }
    });
  }

  static async connect(url: string): Promise<TestClient> {
    const socket = new WebSocket(url);
    await new Promise((resolve, reject) =>
      socket.once('open', resolve).once('error', reject),
    );
    return new TestClient(socket);
  }

  async send(event: string, payload: object = {}): Promise<any> {
    const ref = `r${++this.nextRef}`;
    const reply = this.next(
      (frame) => frame.event === 'reply' && frame.data.ref === ref,
    );
    this.socket.send(JSON.stringify({ event, data: { ref, ...payload } }));
    return (await reply).data;
  }

  next(match: (frame: Frame) => boolean): Promise<Frame> {
    const index = this.inbox.findIndex(match);
    if (index >= 0) return Promise.resolve(this.inbox.splice(index, 1)[0]);
    return new Promise((resolve) => this.waiters.push({ match, resolve }));
  }

  close(): void {
    this.socket.close();
  }
}

/** Captures sign-in codes instead of sending e-mail. */
class InboxMailer {
  readonly codes = new Map<string, string>();

  sendSignInCode(email: string, code: string): Promise<void> {
    this.codes.set(email, code);
    return Promise.resolve();
  }
}

describe('Library realtime protocol (e2e)', () => {
  let app: INestApplication;
  let url: string;
  const inbox = new InboxMailer();

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(Mailer)
      .useValue(inbox)
      .compile();
    app = moduleRef.createNestApplication();
    app.useWebSocketAdapter(new WsAdapter(app));
    await app.listen(0);
    url = `ws://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}/ws`;
  });

  afterAll(async () => {
    await app.close();
  });

  async function signInWithEmail(
    client: TestClient,
    email: string,
    displayName?: string,
  ): Promise<any> {
    expect((await client.send('auth:email-code', { email })).ok).toBe(true);
    const code = inbox.codes.get(email.toLowerCase());
    return client.send('auth', {
      method: 'email',
      email,
      code,
      displayName,
      timeZone: 'Europe/Istanbul',
    });
  }

  async function signedIn(name: string): Promise<TestClient> {
    const client = await TestClient.connect(url);
    const reply = await signInWithEmail(
      client,
      `${name.toLowerCase()}-${randomUUID()}@example.com`,
      name,
    );
    expect(reply.ok).toBe(true);
    return client;
  }

  it('rejects commands before authentication', async () => {
    const client = await TestClient.connect(url);
    const reply = await client.send('room:join');
    expect(reply).toMatchObject({ ok: false, error: { code: 'UNAUTHORIZED' } });
    client.close();
  });

  it('lets two readers share a private hall and see each other sit, break and stand', async () => {
    const alp = await signedIn('Alp');
    const selin = await signedIn('Selin');

    const created = await alp.send('room:create');
    expect(created.ok).toBe(true);
    const { room, layout } = created.result;
    expect(room).toMatchObject({
      type: 'PRIVATE',
      capacity: 30,
      occupiedCount: 0,
    });
    expect(layout.desks).toHaveLength(30);

    const joined = await selin.send('room:join', {
      code: room.code.toLowerCase(),
    });
    expect(joined.result.room.id).toBe(room.id);

    const sat = await alp.send('desk:sit', {
      deskId: 'desk_14',
      taskLabel: 'Swift Concurrency',
    });
    expect(sat.result.desk).toMatchObject({
      deskId: 'desk_14',
      userName: 'Alp',
      status: 'FOCUS',
      sessionNumber: 1,
    });
    const occupied = await selin.next(
      (frame) => frame.event === 'desk:occupied',
    );
    expect(occupied.data.desk.userName).toBe('Alp');

    const taken = await selin.send('desk:sit', {
      deskId: 'desk_14',
      taskLabel: 'Reading',
    });
    expect(taken).toMatchObject({ ok: false, error: { code: 'DESK_TAKEN' } });

    await alp.send('desk:status', { status: 'BREAK' });
    const updated = await selin.next((frame) => frame.event === 'desk:updated');
    expect(updated.data.desk.status).toBe('BREAK');

    const heartbeat = await alp.send('presence:heartbeat', {
      background: true,
    });
    expect(heartbeat.result.leaseExpiresAt).toBeGreaterThan(
      Date.now() + 30 * 60_000,
    );

    await alp.send('desk:stand');
    const vacated = await selin.next((frame) => frame.event === 'desk:vacated');
    expect(vacated.data).toMatchObject({
      deskId: 'desk_14',
      reason: 'STOOD_UP',
    });

    alp.close();
    selin.close();
  });

  it('signs in by e-mail code once, rejecting wrong codes and rapid resends', async () => {
    const client = await TestClient.connect(url);
    const email = `Kod-${randomUUID()}@Example.com`;
    expect((await client.send('auth:email-code', { email })).ok).toBe(true);
    expect(await client.send('auth:email-code', { email })).toMatchObject({
      ok: false,
      error: { code: 'RATE_LIMITED' },
    });

    const wrong = await client.send('auth', {
      method: 'email',
      email,
      code:
        '000000' === inbox.codes.get(email.toLowerCase()) ? '111111' : '000000',
    });
    expect(wrong).toMatchObject({ ok: false, error: { code: 'INVALID_CODE' } });

    const code = inbox.codes.get(email.toLowerCase());
    const first = await client.send('auth', { method: 'email', email, code });
    expect(first.ok).toBe(true);
    expect(first.result.user.displayName).toMatch(/^Kod/);
    expect(
      await client.send('auth', { method: 'email', email, code }),
    ).toMatchObject({ ok: false, error: { code: 'INVALID_CODE' } });
    client.close();
  });

  it('returns a seated reader to their hall when they reconnect with their session token', async () => {
    const first = await TestClient.connect(url);
    const signIn = await signInWithEmail(
      first,
      `baransel-${randomUUID()}@example.com`,
      'Baransel',
    );
    const { result } = await first.send('room:join');
    await first.send('desk:sit', { deskId: 'desk_3', taskLabel: 'Refactor' });
    first.close();

    const second = await TestClient.connect(url);
    const auth = await second.send('auth', {
      method: 'session',
      sessionToken: signIn.result.sessionToken,
    });
    expect(auth.result.user.id).toBe(signIn.result.user.id);
    const resumed = await second.send('room:join');
    expect(resumed.result.room.id).toBe(result.room.id);
    expect(
      resumed.result.desks.find(
        (desk: any) => desk.userId === auth.result.user.id,
      )?.deskId,
    ).toBe('desk_3');

    await second.send('room:leave');
    second.close();
  });

  it('frees a desk whose lease ran out', async () => {
    const watcher = await signedIn('Ece');
    const sleeper = await signedIn('Mert');
    const { result } = await watcher.send('room:create');
    await sleeper.send('room:join', { code: result.room.code });
    const { result: sat } = await sleeper.send('desk:sit', {
      deskId: 'desk_7',
      taskLabel: 'Kafka',
    });

    // Simulate a phone that vanished: backdate the lease instead of waiting for it.
    const redis = app.get(RedisService).client;
    const expired = { ...sat.desk, leaseExpiresAt: Date.now() - 1 };
    await redis.hset(
      RedisKeys.roomDesks(result.room.id),
      'desk_7',
      JSON.stringify(expired),
    );
    await redis.zadd(
      RedisKeys.deskLeases,
      expired.leaseExpiresAt,
      `${result.room.id}|desk_7|${sat.desk.userId}`,
    );

    const vacated = await watcher.next(
      (frame) => frame.event === 'desk:vacated',
    );
    expect(vacated.data).toMatchObject({
      deskId: 'desk_7',
      reason: 'LEASE_EXPIRED',
    });
    expect(await sleeper.send('desk:stand')).toMatchObject({
      ok: false,
      error: { code: 'NOT_SEATED' },
    });

    watcher.close();
    sleeper.close();
  }, 15_000);

  it('rejects unknown codes and malformed payloads', async () => {
    const client = await signedIn('Deniz');
    expect(await client.send('room:join', { code: 'ZZZZZZ' })).toMatchObject({
      ok: false,
      error: { code: 'ROOM_NOT_FOUND' },
    });
    expect(await client.send('room:join', { code: '12' })).toMatchObject({
      ok: false,
      error: { code: 'INVALID_PAYLOAD' },
    });
    expect(
      await client.send('desk:sit', { deskId: 'desk_1', taskLabel: 'x' }),
    ).toMatchObject({
      ok: false,
      error: { code: 'NOT_IN_ROOM' },
    });
    client.close();
  });
});
