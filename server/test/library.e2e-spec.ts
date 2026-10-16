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

  /** A fresh handle like `alp_3f9c1a`, unique across test runs. */
  const handle = (name: string) =>
    `${name.toLowerCase()}_${randomUUID().slice(0, 6)}`;

  function register(
    client: TestClient,
    email: string,
    displayName?: string,
    username = handle('okur'),
  ): Promise<any> {
    return client.send('auth', {
      method: 'register',
      email,
      password,
      username,
      displayName,
      timeZone: 'Europe/Istanbul',
    });
  }

  async function signedInWithId(
    name: string,
  ): Promise<{ client: TestClient; userId: string }> {
    const client = await TestClient.connect(url);
    const reply = await register(
      client,
      `${name.toLowerCase()}-${randomUUID()}@example.com`,
      name,
      handle(name),
    );
    expect(reply.ok).toBe(true);
    return { client, userId: reply.result.user.id };
  }

  async function signedIn(name: string): Promise<TestClient> {
    return (await signedInWithId(name)).client;
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

    const username = handle('Kayit');
    const created = await register(client, email, undefined, username);
    expect(created.ok).toBe(true);
    expect(created.result.user).toMatchObject({
      username,
      displayName: username,
      bio: null,
      statsVisible: true,
    });
    expect(await register(client, email.toLowerCase())).toMatchObject({
      ok: false,
      error: { code: 'EMAIL_TAKEN' },
    });

    const wrong = await client.send('auth', {
      method: 'password',
      login: email,
      password: 'yanlis-sifre',
    });
    expect(wrong).toMatchObject({
      ok: false,
      error: { code: 'INVALID_CREDENTIALS' },
    });
    const loggedIn = await client.send('auth', {
      method: 'password',
      login: email,
      password,
    });
    expect(loggedIn.result.user.id).toBe(created.result.user.id);
    const byUsername = await client.send('auth', {
      method: 'password',
      login: username.toUpperCase(),
      password,
    });
    expect(byUsername.result.user.id).toBe(created.result.user.id);
    client.close();
  });

  it('keeps usernames unique and checks them before sign-up', async () => {
    const client = await TestClient.connect(url);
    const username = handle('Tekil');
    expect((await client.send('username:check', { username })).result).toEqual({
      username,
      available: true,
    });
    expect(
      await client.send('username:check', { username: '.kotu..ad' }),
    ).toMatchObject({ ok: false, error: { code: 'INVALID_PAYLOAD' } });

    await register(client, `${username}@example.com`, undefined, username);
    expect(
      (await client.send('username:check', { username })).result.available,
    ).toBe(false);
    const other = await TestClient.connect(url);
    expect(
      await register(
        other,
        `baska-${randomUUID()}@example.com`,
        'Başka',
        username,
      ),
    ).toMatchObject({ ok: false, error: { code: 'USERNAME_TAKEN' } });
    await register(other, `baska-${randomUUID()}@example.com`);
    expect(await other.send('profile:update', { username })).toMatchObject({
      ok: false,
      error: { code: 'USERNAME_TAKEN' },
    });
    client.close();
    other.close();
  });

  it('ranks the people of a room by weekly focus and honours hidden stats', async () => {
    const { client: owner, userId: ownerId } = await signedInWithId('Ada');
    const { client: shy, userId: shyId } = await signedInWithId('Utangac');
    const { result } = await owner.send('room:create', {
      name: 'Topluluk',
      symbol: 'books.vertical.fill',
      color: 'teal',
      visibility: 'PRIVATE',
    });
    await owner.send('desk:sit', {
      deskId: 'desk_4',
      timer: stopwatch,
      categoryKey: 'software',
    });
    await shy.send('room:join', { code: result.room.code });
    expect(
      (
        await shy.send('profile:update', {
          statsVisible: false,
          bio: 'Selam',
          dailyGoalMinutes: 120,
          weeklyGoalMinutes: 600,
        })
      ).result.user,
    ).toMatchObject({
      statsVisible: false,
      bio: 'Selam',
      dailyGoalMinutes: 120,
      weeklyGoalMinutes: 600,
    });

    const { result: members } = await owner.send('room:members', {
      roomId: result.room.id,
    });
    expect(members.banned).toEqual([]);
    expect(members.people).toHaveLength(2);
    expect(members.people[0]).toMatchObject({
      user: { id: ownerId },
      role: 'OWNER',
      isHere: true,
      desk: { deskId: 'desk_4', category: { key: 'software' } },
    });
    expect(members.people[0].weekFocusMs).toBeGreaterThanOrEqual(0);
    expect(members.people[1]).toMatchObject({
      user: { id: shyId },
      role: 'MEMBER',
      weekFocusMs: null,
    });
    expect(members.people[1].user).not.toHaveProperty('statsVisible');
    expect(
      (await shy.send('room:members', { roomId: result.room.id })).result
        .banned,
    ).toBeNull();

    const hidden = (await owner.send('user:profile', { userId: shyId })).result
      .profile;
    expect(hidden).toMatchObject({
      bio: 'Selam',
      statsVisible: false,
      stats: null,
      dailyGoalMinutes: null,
      isSelf: false,
    });
    expect(
      (await shy.send('user:profile', { userId: shyId })).result.profile
        .dailyGoalMinutes,
    ).toBe(120);
    expect(
      (await shy.send('profile:update', { dailyGoalMinutes: 0 })).result.user
        .dailyGoalMinutes,
    ).toBeNull();
    const open = (await shy.send('user:profile', { userId: ownerId })).result
      .profile;
    expect(open).toMatchObject({
      isSelf: false,
      focusingOn: { key: 'software' },
      stats: { sessionCount: 0, activeDays: 0, requiredDays: 2 },
    });
    expect(
      (await shy.send('user:profile', { userId: shyId })).result.profile.stats,
    ).not.toBeNull();
    owner.close();
    shy.close();
  });

  it('lets the owner remove someone, who cannot come back until unbanned', async () => {
    const { client: owner } = await signedInWithId('Sahip');
    const { client: guest, userId: guestId } = await signedInWithId('Misafir');
    const { result } = await owner.send('room:create', {
      name: 'Sessiz Oda',
      symbol: 'moon.stars.fill',
      color: 'indigo',
      visibility: 'PUBLIC',
    });
    const roomId = result.room.id;
    await guest.send('room:join', { roomId });
    await guest.send('desk:sit', {
      deskId: 'desk_6',
      timer: stopwatch,
      categoryKey: 'study',
    });

    expect(
      await guest.send('room:remove', { roomId, userId: guestId }),
    ).toMatchObject({ ok: false, error: { code: 'FORBIDDEN' } });
    expect(
      (await owner.send('room:remove', { roomId, userId: guestId })).ok,
    ).toBe(true);
    await guest.next(
      (frame) =>
        frame.event === 'desk:vacated' && frame.data.userId === guestId,
    );
    const removed = await guest.next((frame) => frame.event === 'room:removed');
    expect(removed.data).toMatchObject({ roomId, userId: guestId });
    expect((await guest.send('desk:mine')).result.desk).toBeNull();
    expect(
      (await guest.send('room:discover')).result.rooms.map(
        (room: { id: string }) => room.id,
      ),
    ).not.toContain(roomId);
    expect(await guest.send('room:join', { roomId })).toMatchObject({
      ok: false,
      error: { code: 'BANNED' },
    });
    expect(
      (await owner.send('room:members', { roomId })).result.banned,
    ).toMatchObject([{ id: guestId }]);

    const renamed = await owner.send('room:update', {
      roomId,
      name: 'Yeni Ad',
      visibility: 'PRIVATE',
    });
    expect(renamed.result.room).toMatchObject({
      name: 'Yeni Ad',
      kind: 'PRIVATE',
    });
    const updated = await owner.next((frame) => frame.event === 'room:updated');
    expect(updated.data.room).toMatchObject({ id: roomId, name: 'Yeni Ad' });

    expect(
      (await owner.send('room:unban', { roomId, userId: guestId })).ok,
    ).toBe(true);
    expect(
      await guest.send('room:join', { code: result.room.code }),
    ).toMatchObject({ ok: true });
    owner.close();
    guest.close();
  });

  it('shares a private room by code and broadcasts sit, pomodoro break and stand', async () => {
    const alp = await signedIn('Alp');
    const selin = await signedIn('Selin');

    const created = await alp.send('room:create', {
      name: 'Gece Kodlayanlar',
      symbol: 'moon.stars.fill',
      color: 'indigo',
      visibility: 'PRIVATE',
    });
    expect(created.ok).toBe(true);
    const { room, layout } = created.result;
    expect(room).toMatchObject({
      kind: 'PRIVATE',
      name: 'Gece Kodlayanlar',
      symbol: 'moon.stars.fill',
      color: 'indigo',
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
      category: {
        key: 'software',
        symbol: 'chevron.left.forwardslash.chevron.right',
        color: 'blue',
      },
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

  it('ranks public rooms in Keşfet and lists my rooms with live counts', async () => {
    const owner = await signedIn('Ece');
    const visitor = await signedIn('Mert');
    const publicRoom = (
      await owner.send('room:create', {
        name: 'Sessiz Okuma',
        symbol: 'book.fill',
        color: 'brown',
        visibility: 'PUBLIC',
      })
    ).result.room;
    await owner.send('desk:sit', {
      deskId: 'desk_2',
      timer: stopwatch,
      categoryKey: 'reading',
    });

    const discover = (await visitor.send('room:discover')).result;
    expect(discover.layout.desks).toHaveLength(30);
    expect(discover.halls).toMatchObject({ occupiedCount: expect.any(Number) });
    expect(
      discover.rooms.find((room: any) => room.id === publicRoom.id),
    ).toMatchObject({
      symbol: 'book.fill',
      color: 'brown',
      occupiedCount: 1,
      presenceCount: 1,
      memberCount: 1,
      occupants: [
        {
          deskId: 'desk_2',
          userName: 'Ece',
          avatarSpriteId: 'scholar_01',
          resting: false,
        },
      ],
      score: expect.any(Number),
    });
    const scores = discover.rooms.map((room: any) => room.score);
    expect(scores).toEqual([...scores].sort((a, b) => b - a));

    const overview = (await visitor.send('room:list')).result;
    expect(overview.myRooms).toEqual([]);
    expect(overview.seatedRoomId).toBeNull();
    expect(overview.focusingNow).toBeGreaterThanOrEqual(1);

    const myRoomIds = async () =>
      (await visitor.send('room:list')).result.myRooms.map(
        (room: any) => room.id,
      );
    await visitor.send('room:join', { roomId: publicRoom.id });
    expect(await myRoomIds()).toEqual([publicRoom.id]);
    await visitor.send('desk:sit', {
      deskId: 'desk_3',
      timer: stopwatch,
      categoryKey: 'reading',
    });
    expect(await myRoomIds()).toEqual([publicRoom.id]);
    await visitor.send('desk:stand');
    expect(
      (await visitor.send('room:forget', { roomId: publicRoom.id })).ok,
    ).toBe(true);
    expect(await myRoomIds()).toEqual([]);
    expect(
      await owner.send('room:forget', { roomId: publicRoom.id }),
    ).toMatchObject({ ok: false, error: { code: 'FORBIDDEN' } });
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
    expect(mine.result).toMatchObject({
      desk: { deskId: 'desk_3', category: { key: 'study' } },
      room: { id: result.room.id },
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
      symbol: 'guitars.fill',
      color: 'red',
    });
    expect(created.result.category).toMatchObject({
      name: 'Gitar',
      symbol: 'guitars.fill',
      color: 'red',
    });
    expect(
      await reader.send('category:create', {
        name: 'Gitar',
        symbol: 'guitars.fill',
        color: 'red',
      }),
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
      symbol: 'guitars.fill',
      color: 'red',
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
    // The total, not today's minutes: run just after midnight, a backdated session belongs to yesterday.
    expect(stats.totalMs).toBeGreaterThanOrEqual(40 * 60_000);
    expect(stats.streakDays).toBe(1);
    expect(stats.activeDays).toBeGreaterThanOrEqual(1);
    expect(stats.last7Days).toHaveLength(7);
    expect(stats.categories[0]).toMatchObject({ key: 'writing', name: 'Yazı' });
    reader.close();
  });

  it('frees a desk whose lease ran out', async () => {
    const watcher = await signedIn('Ece');
    const sleeper = await signedIn('Mert');
    const { result } = await watcher.send('room:create', {
      name: 'Uyku Testi',
      symbol: 'moon.stars.fill',
      color: 'purple',
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
      symbol: 'bolt.fill',
      color: 'orange',
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

  it('chats in a room: delivery, idempotent retries, history, typing, deletes and limits', async () => {
    const { client: owner, userId: ownerId } = await signedInWithId('Sohbet');
    const { client: guest } = await signedInWithId('Konuk');
    const { result } = await owner.send('room:create', {
      name: 'Sohbet Odası',
      symbol: 'books.vertical.fill',
      color: 'teal',
      visibility: 'PRIVATE',
    });
    expect(
      await guest.send('chat:send', { body: 'erken', clientId: 'c-early-01' }),
    ).toMatchObject({ ok: false, error: { code: 'NOT_IN_ROOM' } });
    await guest.send('room:join', { code: result.room.code });

    const sent = await guest.send('chat:send', {
      body: '  Merhaba!\nNasılsınız?  ',
      clientId: 'c-hello-01',
    });
    expect(sent.result.message).toMatchObject({
      body: 'Merhaba!\nNasılsınız?',
      clientId: 'c-hello-01',
      user: { displayName: 'Konuk' },
    });
    const pushed = await owner.next((frame) => frame.event === 'chat:message');
    expect(pushed.data.message.id).toBe(sent.result.message.id);

    const retried = await guest.send('chat:send', {
      body: 'Merhaba!\nNasılsınız?',
      clientId: 'c-hello-01',
    });
    expect(retried.result.message.id).toBe(sent.result.message.id);
    expect(
      await guest.send('chat:send', { body: '   ', clientId: 'c-blank-01' }),
    ).toMatchObject({ ok: false, error: { code: 'INVALID_PAYLOAD' } });

    await guest.send('chat:typing');
    const typing = await owner.next((frame) => frame.event === 'chat:typing');
    expect(typing.data.user.displayName).toBe('Konuk');

    const mine = await owner.send('chat:send', {
      body: 'Hoş geldin',
      clientId: 'c-welcome-1',
    });
    const history = (await guest.send('chat:history')).result;
    expect(history.hasMore).toBe(false);
    expect(history.messages.map((m: { body: string }) => m.body)).toEqual([
      'Merhaba!\nNasılsınız?',
      'Hoş geldin',
    ]);

    expect(
      await guest.send('chat:delete', { messageId: mine.result.message.id }),
    ).toMatchObject({ ok: false, error: { code: 'FORBIDDEN' } });
    expect(
      (await owner.send('chat:delete', { messageId: sent.result.message.id }))
        .ok,
    ).toBe(true);
    const deleted = await guest.next((frame) => frame.event === 'chat:deleted');
    expect(deleted.data.messageId).toBe(sent.result.message.id);

    const burst = await Promise.all(
      Array.from({ length: 12 }, (_, index) =>
        guest.send('chat:send', {
          body: `#${index}`,
          clientId: `c-burst-${index}0`,
        }),
      ),
    );
    expect(burst.filter((reply) => reply.ok).length).toBeLessThanOrEqual(8);
    expect(burst.some((reply) => reply.error?.code === 'RATE_LIMITED')).toBe(
      true,
    );
    expect(ownerId).toBeTruthy();
    owner.close();
    guest.close();
  });

  it('previews a public room with its description before joining', async () => {
    const { client: owner, userId: ownerId } = await signedInWithId('Tanitan');
    const { client: visitor } = await signedInWithId('Bakan');
    const created = await owner.send('room:create', {
      name: 'Tanıtım Odası',
      symbol: 'books.vertical.fill',
      color: 'indigo',
      visibility: 'PUBLIC',
      description: '  Sabah 9 gibi\nbirlikte KPSS çalışıyoruz  ',
    });
    const roomId = created.result.room.id;
    expect(created.result.room.description).toBe(
      'Sabah 9 gibi\nbirlikte KPSS çalışıyoruz',
    );
    await owner.send('desk:sit', {
      deskId: 'desk_3',
      timer: stopwatch,
      categoryKey: 'study',
    });

    const preview = (await visitor.send('room:preview', { roomId })).result;
    expect(preview).toMatchObject({
      owner: { id: ownerId },
      isMember: false,
      isSeatedHere: false,
      room: {
        id: roomId,
        description: 'Sabah 9 gibi\nbirlikte KPSS çalışıyoruz',
        occupiedCount: 1,
        occupants: [{ deskId: 'desk_3', userId: ownerId }],
      },
    });
    const discovered = (await visitor.send('room:discover')).result.rooms.find(
      (room: { id: string }) => room.id === roomId,
    );
    expect(discovered.description).toBe(
      'Sabah 9 gibi\nbirlikte KPSS çalışıyoruz',
    );

    await owner.send('room:update', { roomId, description: '' });
    expect(
      (await visitor.send('room:preview', { roomId })).result.room.description,
    ).toBeNull();

    const secret = await owner.send('room:create', {
      name: 'Gizli Oda',
      symbol: 'books.vertical.fill',
      color: 'indigo',
      visibility: 'PRIVATE',
    });
    expect(
      await visitor.send('room:preview', { roomId: secret.result.room.id }),
    ).toMatchObject({ ok: false, error: { code: 'FORBIDDEN' } });
    owner.close();
    visitor.close();
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
      await again.send('auth', { method: 'password', login: email, password }),
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
        symbol: 'not.a.symbol',
        color: 'indigo',
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
