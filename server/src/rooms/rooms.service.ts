import { Injectable } from '@nestjs/common';
import { DeskStore } from '../library/desk-store.js';
import { LIBRARY_LAYOUT } from '../library/layout/library-layout.js';
import { RoomKind } from '../library/library.types.js';
import { RoomDirectory, RoomIdentity } from '../library/room-directory.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import {
  RoomRecord,
  RoomsRepository,
  RoomVisibility,
} from './rooms.repository.js';

const MAX_OWNED_ROOMS = 10;

export interface RoomSummary {
  id: string;
  kind: RoomKind;
  name: string;
  emoji: string;
  code: string | null;
  ownerId: string | null;
  capacity: number;
  presenceCount: number;
  occupiedCount: number;
}

export interface RoomsOverview {
  halls: RoomSummary[];
  publicRooms: RoomSummary[];
  myRooms: RoomSummary[];
  /** The room where the reader still holds a desk, if any. */
  seatedRoomId: string | null;
}

export type RoomTarget = { roomId?: string; code?: string };

/** The catalogue of rooms: system halls plus user-created public and private rooms. */
@Injectable()
export class RoomsService {
  constructor(
    private readonly rooms: RoomsRepository,
    private readonly directory: RoomDirectory,
    private readonly desks: DeskStore,
  ) {}

  async overview(userId: string, now: number): Promise<RoomsOverview> {
    const [hallIds, publicRooms, myRooms, seat] = await Promise.all([
      this.directory.hallIds(),
      this.rooms.listPublic(),
      this.rooms.listMine(userId),
      this.desks.seatOf(userId),
    ]);
    const identities = [
      ...hallIds.map((id) => RoomDirectory.hallIdentity(id)),
      ...[...publicRooms, ...myRooms].map((room) =>
        RoomsService.identity(room),
      ),
    ];
    const counts = await this.directory.liveCounts(
      [...new Set(identities.map((room) => room.id))],
      now,
    );
    const summary = (room: RoomIdentity): RoomSummary => ({
      ...room,
      capacity: LIBRARY_LAYOUT.desks.length,
      ...counts.get(room.id)!,
    });

    return {
      halls: hallIds.map((id) => summary(RoomDirectory.hallIdentity(id))),
      publicRooms: publicRooms
        .map((room) => summary(RoomsService.identity(room)))
        .sort(
          (a, b) =>
            b.presenceCount +
            b.occupiedCount -
            (a.presenceCount + a.occupiedCount),
        ),
      myRooms: myRooms.map((room) => summary(RoomsService.identity(room))),
      seatedRoomId: seat?.roomId ?? null,
    };
  }

  async create(
    ownerId: string,
    name: string,
    emoji: string,
    visibility: RoomVisibility,
  ): Promise<RoomIdentity> {
    if ((await this.rooms.countOwned(ownerId)) >= MAX_OWNED_ROOMS) {
      ProtocolError.throw(
        'LIMIT_REACHED',
        `At most ${MAX_OWNED_ROOMS} rooms per reader`,
      );
    }
    return RoomsService.identity(
      await this.rooms.create(ownerId, name, emoji, visibility),
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
    if (
      room.visibility === 'PRIVATE' &&
      !(await this.rooms.isMember(userId, room.id))
    ) {
      ProtocolError.throw('FORBIDDEN', 'Join this room with its code');
    }
    await this.rooms.touchMembership(userId, room.id);
    return RoomsService.identity(room);
  }

  private static identity(room: RoomRecord): RoomIdentity {
    return {
      id: room.id,
      kind: room.visibility,
      name: room.name,
      emoji: room.emoji,
      code: room.code,
      ownerId: room.ownerId,
    };
  }
}
