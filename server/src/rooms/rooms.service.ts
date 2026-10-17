import { Injectable } from '@nestjs/common';
import { Glyph } from '../common/glyph.js';
import { RedisService } from '../infra/redis.service.js';
import {
  FREE_ROOM_LIMIT,
  PLUS_ROOM_LIMIT,
  PLUS_THEMES,
} from '../plus/plus-catalog.js';
import { PlusService } from '../plus/plus.service.js';
import { DeskStore } from '../library/desk-store.js';
import { readTimer } from '../library/desk-timer.js';
import {
  getLayoutForTheme,
  LAYOUTS_BY_THEME,
  LIBRARY_LAYOUT,
  LibraryLayout,
} from '../library/layout/library-layout.js';
import { RoomKind } from '../library/library.types.js';
import { RoomDirectory, RoomIdentity } from '../library/room-directory.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import {
  RoomRecord,
  RoomsRepository,
  RoomVisibility,
} from './rooms.repository.js';
import { discoverScore } from './discover-score.js';
import { PublicUser } from '../users/user.js';
import { RoomActivity, RoomActivityRepository } from './room-activity.js';

/** Keşfet is the same for everyone apart from bans and the reader's own desk, so it is built once per window. */
const DISCOVER_CACHE_KEY = 'discover:shared';
const DISCOVER_CACHE_SECONDS = 15;

type SharedDiscover = Pick<DiscoverResult, 'halls' | 'rooms'>;

export interface RoomSummary {
  id: string;
  kind: RoomKind;
  name: string;
  symbol: string;
  color: string;
  theme: string;
  description: string | null;
  code: string | null;
  ownerId: string | null;
  capacity: number;
  presenceCount: number;
  occupiedCount: number;
  /** Who sits where, for the room's preview card. */
  occupants: RoomOccupant[];
}

export interface RoomOccupant {
  deskId: string;
  userId: string;
  userName: string;
  avatarSpriteId: string;
  resting: boolean;
}

export interface RoomsOverview {
  /** The classic floor plan, for rooms without a theme of their own. */
  layout: LibraryLayout;
  /** Floor plans by theme, so each card previews its room's look. */
  layouts: Record<string, LibraryLayout>;
  myRooms: RoomSummary[];
  /** The room where the reader still holds a desk, if any. */
  seatedRoomId: string | null;
  /** People at a desk in halls and public rooms right now, for the Keşfet entry. */
  focusingNow: number;
}

export interface DiscoverRoom extends RoomSummary, RoomActivity {
  memberCount: number;
  createdAt: number;
  score: number;
}

export interface DiscoverResult {
  layout: LibraryLayout;
  layouts: Record<string, LibraryLayout>;
  seatedRoomId: string | null;
  /** All system halls together: "Hemen Başla" seats the reader in one with space. */
  halls: { occupiedCount: number; presenceCount: number };
  /** Public rooms, best first. */
  rooms: DiscoverRoom[];
}

/** Everything shown about a public room before joining it. */
export interface RoomPreviewResult {
  layout: LibraryLayout;
  room: DiscoverRoom;
  owner: PublicUser | null;
  isMember: boolean;
  isSeatedHere: boolean;
}

export type RoomTarget = { roomId?: string; code?: string };

/** The catalogue of rooms: system halls plus user-created public and private rooms. */
@Injectable()
export class RoomsService {
  constructor(
    private readonly rooms: RoomsRepository,
    private readonly directory: RoomDirectory,
    private readonly desks: DeskStore,
    private readonly activity: RoomActivityRepository,
    private readonly redis: RedisService,
    private readonly plus: PlusService,
  ) {}

  async overview(userId: string, now: number): Promise<RoomsOverview> {
    // The open library's head count comes from the shared Keşfet cache, not a fresh scan.
    const [shared, myRooms, seat] = await Promise.all([
      this.sharedDiscover(now),
      this.rooms.listMine(userId),
      this.desks.seatOf(userId),
    ]);
    return {
      layout: LIBRARY_LAYOUT,
      layouts: LAYOUTS_BY_THEME,
      myRooms: await this.summaries(
        myRooms.map((room) => RoomsService.identity(room)),
        now,
      ),
      seatedRoomId: seat?.roomId ?? null,
      focusingNow: shared.rooms.reduce(
        (sum, room) => sum + room.occupiedCount,
        shared.halls.occupiedCount,
      ),
    };
  }

  async discover(userId: string, now: number): Promise<DiscoverResult> {
    const [shared, seat, bannedIds] = await Promise.all([
      this.sharedDiscover(now),
      this.desks.seatOf(userId),
      this.rooms.bannedRoomIds(userId),
    ]);
    return {
      layout: LIBRARY_LAYOUT,
      layouts: LAYOUTS_BY_THEME,
      seatedRoomId: seat?.roomId ?? null,
      halls: shared.halls,
      rooms: shared.rooms.filter((room) => !bannedIds.has(room.id)),
    };
  }

  private static isPlusTheme(theme: string): boolean {
    return (PLUS_THEMES as readonly string[]).includes(theme);
  }

  /** Rooms appeared, changed or went away: rebuild Keşfet on the next request. */
  private async forgetDiscover(): Promise<void> {
    await this.redis.client.del(DISCOVER_CACHE_KEY);
  }

  /** Every public room ranked, plus the halls' totals; cached briefly in Redis for all readers. */
  private async sharedDiscover(now: number): Promise<SharedDiscover> {
    const cached = await this.redis.client.get(DISCOVER_CACHE_KEY);
    if (cached) return JSON.parse(cached) as SharedDiscover;

    const [hallIds, publicRooms] = await Promise.all([
      this.directory.hallIds(),
      this.rooms.listPublic(),
    ]);
    const roomIds = publicRooms.map((room) => room.id);
    const [summaries, hallCounts, activity, members] = await Promise.all([
      this.summaries(
        publicRooms.map((room) => RoomsService.identity(room)),
        now,
      ),
      this.directory.liveCounts(hallIds, now),
      this.activity.forRooms(roomIds, now),
      this.rooms.memberCounts(roomIds),
    ]);

    const rooms = summaries.map((summary, index): DiscoverRoom => {
      const record = publicRooms[index];
      const roomActivity = activity.get(summary.id) ?? {
        weeklyFocusMs: 0,
        weeklyReaders: 0,
        decayedFocusHours: 0,
        topic: null,
      };
      const memberCount = members.get(summary.id) ?? 0;
      const createdAt = record.createdAt.getTime();
      return {
        ...summary,
        ...roomActivity,
        memberCount,
        createdAt,
        score: discoverScore({
          ...summary,
          ...roomActivity,
          memberCount,
          ageHours: (now - createdAt) / 3_600_000,
        }),
      };
    });

    const hallTotals = [...hallCounts.values()];
    const shared: SharedDiscover = {
      halls: {
        occupiedCount: hallTotals.reduce(
          (sum, count) => sum + count.occupiedCount,
          0,
        ),
        presenceCount: hallTotals.reduce(
          (sum, count) => sum + count.presenceCount,
          0,
        ),
      },
      rooms: rooms.sort((a, b) => b.score - a.score),
    };
    await this.redis.client.set(
      DISCOVER_CACHE_KEY,
      JSON.stringify(shared),
      'EX',
      DISCOVER_CACHE_SECONDS,
    );
    return shared;
  }

  /** A room's card, blurb, owner and who is inside, for deciding whether to join. */
  async preview(
    userId: string,
    roomId: string,
    now: number,
  ): Promise<RoomPreviewResult> {
    const record =
      (await this.rooms.findById(roomId)) ??
      ProtocolError.throw('ROOM_NOT_FOUND', 'Room no longer exists');
    const [isMember, isBanned, seat] = await Promise.all([
      this.rooms.isMember(userId, roomId),
      this.rooms.isBanned(userId, roomId),
      this.desks.seatOf(userId),
    ]);
    if (isBanned)
      ProtocolError.throw('BANNED', 'The owner removed you from this room');
    if (record.visibility === 'PRIVATE' && !isMember)
      ProtocolError.throw('FORBIDDEN', 'Join this room with its code');

    const [[summary], activity, members, owner] = await Promise.all([
      this.summaries([RoomsService.identity(record)], now),
      this.activity.forRooms([roomId], now),
      this.rooms.memberCounts([roomId]),
      this.rooms.owner(roomId),
    ]);
    const roomActivity = activity.get(roomId) ?? {
      weeklyFocusMs: 0,
      weeklyReaders: 0,
      decayedFocusHours: 0,
      topic: null,
    };
    const memberCount = members.get(roomId) ?? 0;
    const createdAt = record.createdAt.getTime();
    return {
      layout: getLayoutForTheme(record.theme),
      room: {
        ...summary,
        ...roomActivity,
        memberCount,
        createdAt,
        score: discoverScore({
          ...summary,
          ...roomActivity,
          memberCount,
          ageHours: (now - createdAt) / 3_600_000,
        }),
      },
      owner,
      isMember,
      isSeatedHere: seat?.roomId === roomId,
    };
  }

  /** Identity plus live counts and who sits where. */
  private async summaries(
    identities: RoomIdentity[],
    now: number,
  ): Promise<RoomSummary[]> {
    const roomIds = identities.map((room) => room.id);
    const [counts, desks] = await Promise.all([
      this.directory.liveCounts(roomIds, now),
      this.desks.listMany(roomIds),
    ]);
    return identities.map((room) => ({
      ...room,
      capacity: LIBRARY_LAYOUT.desks.length,
      ...counts.get(room.id)!,
      occupants: desks.get(room.id)!.map((desk) => ({
        deskId: desk.deskId,
        userId: desk.userId,
        userName: desk.userName,
        avatarSpriteId: desk.avatarSpriteId,
        resting: readTimer(desk.timer, now).phase === 'BREAK',
      })),
    }));
  }

  async create(
    ownerId: string,
    name: string,
    glyph: Glyph,
    visibility: RoomVisibility,
    theme: string = 'classic',
    description: string | null = null,
  ): Promise<RoomIdentity> {
    const [owned, isPlus] = await Promise.all([
      this.rooms.countOwned(ownerId),
      this.plus.isActive(ownerId),
    ]);
    if (owned >= PLUS_ROOM_LIMIT)
      ProtocolError.throw(
        'LIMIT_REACHED',
        `At most ${PLUS_ROOM_LIMIT} rooms per reader`,
      );
    if (!isPlus && owned >= FREE_ROOM_LIMIT)
      ProtocolError.throw(
        'PLUS_REQUIRED',
        `Free readers can own ${FREE_ROOM_LIMIT} rooms`,
      );
    if (!isPlus && RoomsService.isPlusTheme(theme))
      ProtocolError.throw('PLUS_REQUIRED', 'This theme needs PomoLive Plus');
    const created = RoomsService.identity(
      await this.rooms.create(
        ownerId,
        name,
        glyph,
        visibility,
        theme,
        description,
      ),
    );
    await this.forgetDiscover();
    return created;
  }

  /**
   * Which room a `room:join` leads to. Without a target the reader returns to the room where they
   * still hold a desk, or is routed to a hall with space. Private rooms need the code once.
   */
  async resolve(
    userId: string,
    target: RoomTarget,
    now: number,
  ): Promise<RoomIdentity> {
    if (target.code) {
      const room =
        (await this.rooms.findByCode(target.code)) ??
        ProtocolError.throw('ROOM_NOT_FOUND', 'No room with this code');
      await this.ensureNotBanned(userId, room.id);
      await this.rooms.touchMembership(userId, room.id);
      return RoomsService.identity(room);
    }
    if (target.roomId) return this.resolveById(userId, target.roomId);

    const seat = await this.desks.seatOf(userId);
    if (seat) {
      const seatRoom = await this.resolveById(userId, seat.roomId).catch(
        () => null,
      );
      if (seatRoom) return seatRoom;
    }
    return RoomDirectory.hallIdentity(await this.directory.assignHall(now));
  }

  /** Applies the owner's edits to name, icon, visibility or theme. */
  async update(
    ownerId: string,
    roomId: string,
    changes: Partial<
      Pick<
        RoomRecord,
        'name' | 'symbol' | 'color' | 'visibility' | 'theme' | 'description'
      >
    >,
  ): Promise<RoomIdentity> {
    const current = await this.owned(ownerId, roomId);
    // A room keeps a Plus look it already has; switching to one needs Plus.
    if (
      changes.theme &&
      changes.theme !== current.theme &&
      RoomsService.isPlusTheme(changes.theme)
    )
      await this.plus.require(ownerId);
    const updated = RoomsService.identity(
      await this.rooms.update(roomId, changes),
    );
    await this.forgetDiscover();
    return updated;
  }

  /** Removes a reader from the owner's room and keeps them out. */
  async ban(ownerId: string, roomId: string, userId: string): Promise<void> {
    await this.owned(ownerId, roomId);
    if (userId === ownerId)
      ProtocolError.throw('FORBIDDEN', 'Owners cannot remove themselves');
    await this.rooms.ban(userId, roomId);
  }

  async unban(ownerId: string, roomId: string, userId: string): Promise<void> {
    await this.owned(ownerId, roomId);
    await this.rooms.unban(userId, roomId);
  }

  /** Removes a room from the reader's "Odalarım". Owners delete their rooms instead. */
  async forget(userId: string, roomId: string): Promise<void> {
    const room = await this.rooms.findById(roomId);
    if (room?.ownerId === userId) {
      ProtocolError.throw('FORBIDDEN', 'Owners delete their room instead');
    }
    await this.rooms.removeMembership(userId, roomId);
  }

  /** The room, if `userId` owns it; otherwise a protocol error. */
  async owned(userId: string, roomId: string): Promise<RoomRecord> {
    const room =
      (await this.rooms.findById(roomId)) ??
      ProtocolError.throw('ROOM_NOT_FOUND', 'Room no longer exists');
    if (room.ownerId !== userId)
      ProtocolError.throw('FORBIDDEN', 'Only the owner can do this');
    return room;
  }

  ownedRoomIds(userId: string): Promise<string[]> {
    return this.rooms.ownedRoomIds(userId);
  }

  async delete(roomId: string): Promise<void> {
    await this.rooms.delete(roomId);
    await this.forgetDiscover();
  }

  private async resolveById(
    userId: string,
    roomId: string,
  ): Promise<RoomIdentity> {
    if (RoomDirectory.isHallId(roomId)) {
      if (!(await this.directory.hallIds()).includes(roomId))
        ProtocolError.throw('ROOM_NOT_FOUND', 'This hall has closed');
      return RoomDirectory.hallIdentity(roomId);
    }
    const room =
      (await this.rooms.findById(roomId)) ??
      ProtocolError.throw('ROOM_NOT_FOUND', 'Room no longer exists');
    await this.ensureNotBanned(userId, room.id);
    const isMember = await this.rooms.isMember(userId, room.id);
    if (room.visibility === 'PRIVATE' && !isMember) {
      ProtocolError.throw('FORBIDDEN', 'Join this room with its code');
    }
    // Joining is a deliberate step after the room's preview, so it makes the room one of "Odalarım".
    await this.rooms.touchMembership(userId, room.id);
    return RoomsService.identity(room);
  }

  private async ensureNotBanned(userId: string, roomId: string): Promise<void> {
    if (await this.rooms.isBanned(userId, roomId))
      ProtocolError.throw('BANNED', 'The owner removed you from this room');
  }

  private static identity(room: RoomRecord): RoomIdentity {
    return {
      id: room.id,
      kind: room.visibility,
      name: room.name,
      symbol: room.symbol,
      color: room.color,
      theme: room.theme,
      description: room.description,
      code: room.code,
      ownerId: room.ownerId,
    };
  }
}
