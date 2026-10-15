import { Injectable } from '@nestjs/common';
import { Glyph } from '../common/glyph.js';
import { DeskStore } from '../library/desk-store.js';
import { readTimer } from '../library/desk-timer.js';
import {
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
import { RoomActivity, RoomActivityRepository } from './room-activity.js';

const MAX_OWNED_ROOMS = 10;

export interface RoomSummary {
  id: string;
  kind: RoomKind;
  name: string;
  symbol: string;
  color: string;
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
  userName: string;
  avatarSpriteId: string;
  resting: boolean;
}

export interface RoomsOverview {
  /** The floor plan every room shares, so cards can draw previews. */
  layout: LibraryLayout;
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
  seatedRoomId: string | null;
  /** All system halls together: "Hemen Başla" seats the reader in one with space. */
  halls: { occupiedCount: number; presenceCount: number };
  /** Public rooms, best first. */
  rooms: DiscoverRoom[];
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
  ) {}

  async overview(userId: string, now: number): Promise<RoomsOverview> {
    const [hallIds, publicRooms, myRooms, seat] = await Promise.all([
      this.directory.hallIds(),
      this.rooms.listPublic(),
      this.rooms.listMine(userId),
      this.desks.seatOf(userId),
    ]);
    const openCounts = await this.directory.liveCounts(
      [...hallIds, ...publicRooms.map((room) => room.id)],
      now,
    );
    return {
      layout: LIBRARY_LAYOUT,
      myRooms: await this.summaries(
        myRooms.map((room) => RoomsService.identity(room)),
        now,
      ),
      seatedRoomId: seat?.roomId ?? null,
      focusingNow: [...openCounts.values()].reduce(
        (sum, count) => sum + count.occupiedCount,
        0,
      ),
    };
  }

  async discover(userId: string, now: number): Promise<DiscoverResult> {
    const [hallIds, listed, seat, bannedIds] = await Promise.all([
      this.directory.hallIds(),
      this.rooms.listPublic(),
      this.desks.seatOf(userId),
      this.rooms.bannedRoomIds(userId),
    ]);
    const publicRooms = listed.filter((room) => !bannedIds.has(room.id));
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
    return {
      layout: LIBRARY_LAYOUT,
      seatedRoomId: seat?.roomId ?? null,
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
  ): Promise<RoomIdentity> {
    if ((await this.rooms.countOwned(ownerId)) >= MAX_OWNED_ROOMS) {
      ProtocolError.throw(
        'LIMIT_REACHED',
        `At most ${MAX_OWNED_ROOMS} rooms per reader`,
      );
    }
    return RoomsService.identity(
      await this.rooms.create(ownerId, name, glyph, visibility),
    );
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

  /** Applies the owner's edits to name, icon or visibility. */
  async update(
    ownerId: string,
    roomId: string,
    changes: Partial<
      Pick<RoomRecord, 'name' | 'symbol' | 'color' | 'visibility'>
    >,
  ): Promise<RoomIdentity> {
    await this.owned(ownerId, roomId);
    return RoomsService.identity(await this.rooms.update(roomId, changes));
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
    // Only browsing a public room does not add it to "Odalarım"; sitting down there does.
    if (isMember) await this.rooms.touchMembership(userId, room.id);
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
      code: room.code,
      ownerId: room.ownerId,
    };
  }
}
