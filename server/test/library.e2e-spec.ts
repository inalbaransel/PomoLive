import { INestApplication } from '@nestjs/common';
import { WsAdapter } from '@nestjs/platform-ws';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'node:crypto';
import { AddressInfo } from 'node:net';
import { WebSocket } from 'ws';
import { AppModule } from '../src/app.module.js';
import { RedisService } from '../src/infra/redis.service.js';
import { RedisKeys } from '../src/library/redis-keys.js';

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

describe('Library realtime protocol (e2e)', () => {
  let app: INestApplication;
  let url: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useWebSocketAdapter(new WsAdapter(app));
    await app.listen(0);
    url = `ws://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}/ws`;
  });

  afterAll(async () => {
    await app.close();
  });

  const password = 'kütüphane-2026';

  function register(
    client: TestClient,
    email: string,
    displayName?: string,
  ): Promise<any> {
    return client.send('auth', {
      method: 'register',
      email,
      password,
      displayName,
      timeZone: 'Europe/Istanbul',
    });
  }

  async function signedIn(name: string): Promise<TestClient> {
    const client = await TestClient.connect(url);
    const reply = await register(
      client,
      `${name.toLowerCase()}-${randomUUID()}@example.com`,
      name,
    );
    expect(reply.ok).toBe(true);
    return client;
  }

  const pomodoro = { mode: 'POMODORO', focusMinutes: 25, breakMinutes: 5 };
  const stopwatch = { mode: 'STOPWATCH' };

  it('rejects commands before authentication', async () => {
    const client = await TestClient.connect(url);
    const reply = await client.send('room:join');
    expect(reply).toMatchObject({ ok: false, error: { code: 'UNAUTHORIZED' } });
    client.close();
  });

  it('registers with e-mail and password, then logs in with the same credentials only', async () => {
    const client = await TestClient.connect(url);
    const email = `Kayit-${randomUUID()}@Example.com`;

    const created = await register(client, email);
    expect(created.ok).toBe(true);
    expect(created.result.user.displayName).toMatch(/^Kayit/);
    expect(await register(client, email.toLowerCase())).toMatchObject({
      ok: false,
      error: { code: 'EMAIL_TAKEN' },
    });

    const wrong = await client.send('auth', {
      method: 'password',
      email,
      password: 'yanlis-sifre',
    });
    expect(wrong).toMatchObject({
      ok: false,
      error: { code: 'INVALID_CREDENTIALS' },
    });
    const loggedIn = await client.send('auth', {
      method: 'password',
      email,
      password,
    });
    expect(loggedIn.result.user.id).toBe(created.result.user.id);
    client.close();
  });

  it('shares a private room by code and broadcasts sit, pomodoro break and stand', async () => {
    const alp = await signedIn('Alp');
    const selin = await signedIn('Selin');

    const created = await alp.send('room:create', {
      name: 'Gece Kodlayanlar',
      emoji: '🌙',
      visibility: 'PRIVATE',
    });
    expect(created.ok).toBe(true);
    const { room, layout } = created.result;
    expect(room).toMatchObject({
      kind: 'PRIVATE',
      name: 'Gece Kodlayanlar',
      emoji: '🌙',
      capacity: 30,
    });
    expect(layout.desks).toHaveLength(30);

    expect(await selin.send('room:join', { roomId: room.id })).toMatchObject({
      ok: false,
      error: { code: 'FORBIDDEN' },
    });
    const joined = await selin.send('room:join', {
      code: room.code.toLowerCase(),
    });
    expect(joined.result.room.id).toBe(room.id);
    expect((await selin.send('room:join', { roomId: room.id })).ok).toBe(true);

    const sat = await alp.send('desk:sit', {
      deskId: 'desk_14',
      timer: pomodoro,
      categoryKey: 'software',
      note: 'Swift Concurrency',
    });
    expect(sat.result.desk).toMatchObject({
      deskId: 'desk_14',
      userName: 'Alp',
      category: { key: 'software', emoji: '💻' },
      note: 'Swift Concurrency',
      timer: { mode: 'POMODORO', focusMinutes: 25, breakMinutes: 5 },
    });
    const occupied = await selin.next(
      (frame) => frame.event === 'desk:occupied',
    );
    expect(occupied.data).toMatchObject({
      roomId: room.id,
      desk: { userName: 'Alp' },
    });

    const taken = await selin.send('desk:sit', {
      deskId: 'desk_14',
      timer: stopwatch,
      categoryKey: 'reading',
    });
    expect(taken).toMatchObject({ ok: false, error: { code: 'DESK_TAKEN' } });

    await alp.send('desk:timer', { action: 'BREAK' });
    const updated = await selin.next((frame) => frame.event === 'desk:updated');
    expect(updated.data.desk.timer.bankedFocusMs).toBeLessThan(0);

    await alp.send('desk:stand');
    const vacated = await selin.next((frame) => frame.event === 'desk:vacated');
    expect(vacated.data).toMatchObject({
      deskId: 'desk_14',
      reason: 'STOOD_UP',
    });
    alp.close();
    selin.close();
  });

  it('lists halls, public rooms and my rooms with live counts', async () => {
    const owner = await signedIn('Ece');
    const visitor = await signedIn('Mert');
    const publicRoom = (
      await owner.send('room:create', {
        name: 'Sessiz Okuma',
        emoji: '📖',
        visibility: 'PUBLIC',
      })
    ).result.room;
    await owner.send('desk:sit', {
      deskId: 'desk_2',
      timer: stopwatch,
      categoryKey: 'reading',
    });

    const overview = (await visitor.send('room:list')).result;
    expect(overview.halls.length).toBeGreaterThan(0);
    expect(
      overview.publicRooms.find((room: any) => room.id === publicRoom.id),
    ).toMatchObject({ occupiedCount: 1, presenceCount: 1 });
    expect(overview.myRooms).toEqual([]);
    expect(overview.seatedRoomId).toBeNull();

    await visitor.send('room:join', { roomId: publicRoom.id });
    expect(
      (await visitor.send('room:list')).result.myRooms.map(
        (room: any) => room.id,
      ),
    ).toEqual([publicRoom.id]);
    expect((await owner.send('room:list')).result.seatedRoomId).toBe(
      publicRoom.id,
    );
    owner.close();
    visitor.close();
  });

  it('keeps the desk while the reader browses elsewhere, and returns them to it', async () => {
    const reader = await signedIn('Baransel');
    const { result } = await reader.send('room:join');
    await reader.send('desk:sit', {
      deskId: 'desk_3',
      timer: stopwatch,
      categoryKey: 'study',
    });
    await reader.send('room:leave');

    const mine = await reader.send('desk:mine');
    expect(mine.result.desk).toMatchObject({
      deskId: 'desk_3',
      category: { key: 'study' },
    });
    const resumed = await reader.send('room:join');
    expect(resumed.result.room.id).toBe(result.room.id);
    await reader.send('desk:stand');
    reader.close();
  });

  it('lets readers use their own categories', async () => {
    const reader = await signedIn('Deniz');
    const created = await reader.send('category:create', {
      name: 'Gitar',
      emoji: '🎸',
    });
    expect(created.result.category).toMatchObject({
      name: 'Gitar',
      emoji: '🎸',
    });
    expect(
      await reader.send('category:create', { name: 'Gitar', emoji: '🎸' }),
    ).toMatchObject({ ok: false, error: { code: 'NAME_TAKEN' } });

    const list = (await reader.send('category:list')).result;
    expect(list.builtIn).toHaveLength(8);
    expect(list.custom.map((category: any) => category.key)).toEqual([
      created.result.category.key,
    ]);

    await reader.send('room:join');
    const sat = await reader.send('desk:sit', {
      deskId: 'desk_5',
      timer: stopwatch,
      categoryKey: created.result.category.key,
    });
    expect(sat.result.desk.category).toMatchObject({
      name: 'Gitar',
      emoji: '🎸',
    });
    expect(
      await reader.send('desk:sit', {
        deskId: 'desk_6',
        timer: stopwatch,
        categoryKey: 'custom:00000000-0000-4000-8000-000000000000',
      }),
    ).toMatchObject({
      ok: false,
      error: { code: 'CATEGORY_NOT_FOUND' },
    });
    await reader.send('desk:stand');
    reader.close();
  });

  it('records finished sessions into history and stats', async () => {
    const reader = await signedIn('Zeynep');
    const { result } = await reader.send('room:join');
    const sat = await reader.send('desk:sit', {
      deskId: 'desk_8',
      timer: stopwatch,
      categoryKey: 'writing',
      note: 'Tez',
    });

    // Pretend the reader sat down 40 minutes ago instead of waiting.
    const redis = app.get(RedisService).client;
    const fortyMinutesAgo = Date.now() - 40 * 60_000;
    const backdated = {
      ...sat.result.desk,
      startedAt: fortyMinutesAgo,
      timer: { ...sat.result.desk.timer, since: fortyMinutesAgo },
    };
    await redis.hset(
      RedisKeys.roomDesks(result.room.id),
      'desk_8',
      JSON.stringify(backdated),
    );
    await reader.send('desk:stand');

    const history = (await reader.send('history:list')).result;
    expect(history.hasMore).toBe(false);
    expect(history.entries).toHaveLength(1);
    expect(history.entries[0]).toMatchObject({
      mode: 'STOPWATCH',
      category: { key: 'writing' },
      note: 'Tez',
      roomName: result.room.name,
    });
    expect(history.entries[0].focusedMs).toBeGreaterThanOrEqual(40 * 60_000);

    const stats = (await reader.send('stats:summary')).result;
    expect(stats.sessionCount).toBe(1);
    expect(stats.todayMs).toBeGreaterThanOrEqual(40 * 60_000);
    expect(stats.streakDays).toBe(1);
    expect(stats.last7Days).toHaveLength(7);
    expect(stats.categories[0]).toMatchObject({ key: 'writing', name: 'Yazı' });
    reader.close();
  });

  it('frees a desk whose lease ran out', async () => {
    const watcher = await signedIn('Ece');
    const sleeper = await signedIn('Mert');
    const { result } = await watcher.send('room:create', {
      name: 'Uyku Testi',
      emoji: '😴',
      visibility: 'PRIVATE',
    });
    await sleeper.send('room:join', { code: result.room.code });
    const { result: sat } = await sleeper.send('desk:sit', {
      deskId: 'desk_7',
      timer: pomodoro,
      categoryKey: 'other',
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

  it('lets only the owner delete a room, closing it for everyone inside', async () => {
    const owner = await signedIn('Kaan');
    const guest = await signedIn('Lale');
    const { result } = await owner.send('room:create', {
      name: 'Geçici Oda',
      emoji: '⏳',
      visibility: 'PUBLIC',
    });
    await guest.send('room:join', { roomId: result.room.id });
    await guest.send('desk:sit', {
      deskId: 'desk_1',
      timer: stopwatch,
      categoryKey: 'other',
    });

    expect(
      await guest.send('room:delete', { roomId: result.room.id }),
    ).toMatchObject({ ok: false, error: { code: 'FORBIDDEN' } });
    expect(
      (await owner.send('room:delete', { roomId: result.room.id })).ok,
    ).toBe(true);
    expect(
      (await guest.next((frame) => frame.event === 'desk:vacated')).data.reason,
    ).toBe('ROOM_CLOSED');
    await guest.next((frame) => frame.event === 'room:closed');
    expect(
      await guest.send('room:join', { roomId: result.room.id }),
    ).toMatchObject({ ok: false, error: { code: 'ROOM_NOT_FOUND' } });
    owner.close();
    guest.close();
  });

  it('deletes an account only with the right password', async () => {
    const client = await TestClient.connect(url);
    const email = `silinecek-${randomUUID()}@example.com`;
    await register(client, email);
    expect(
      await client.send('account:delete', { password: 'yanlis-sifre' }),
    ).toMatchObject({ ok: false, error: { code: 'INVALID_CREDENTIALS' } });
    expect((await client.send('account:delete', { password })).ok).toBe(true);

    const again = await TestClient.connect(url);
    expect(
      await again.send('auth', { method: 'password', email, password }),
    ).toMatchObject({ ok: false, error: { code: 'INVALID_CREDENTIALS' } });
    again.close();
  });

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
      await client.send('room:create', {
        name: 'x',
        emoji: 'a',
        visibility: 'PUBLIC',
      }),
    ).toMatchObject({ ok: false, error: { code: 'INVALID_PAYLOAD' } });
    expect(
      await client.send('desk:sit', {
        deskId: 'desk_1',
        timer: stopwatch,
        categoryKey: 'other',
      }),
    ).toMatchObject({
      ok: false,
      error: { code: 'NOT_IN_ROOM' },
    });
    client.close();
  });
});
