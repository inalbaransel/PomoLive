import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { DeskStore } from '../library/desk-store.js';
import { readTimer } from '../library/desk-timer.js';
import { FocusSessionsRepository } from '../library/focus-sessions.repository.js';
import { ReaderSession } from '../library/library.service.js';
import { DAY_MS } from '../library/local-day.js';
import { RoomDirectory } from '../library/room-directory.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { RoomsRepository } from '../rooms/rooms.repository.js';
import { PublicUser } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';

const LEADERBOARD_WINDOW_MS = 7 * DAY_MS;

export type MemberRole = 'OWNER' | 'MEMBER' | 'GUEST';

export interface RoomPerson {
  user: PublicUser;
  role: MemberRole;
  /** Looking at the room or holding a desk in it. */
  isHere: boolean;
  desk: { deskId: string; category: CategoryInfo; resting: boolean } | null;
  /** Focus in this room over the last 7 days, live desk included; `null` if the reader hides it. */
  weekFocusMs: number | null;
}

export interface RoomMembers {
  /** Most focused first. */
  people: RoomPerson[];
  /** Readers the owner removed; only sent to the owner. */
  banned: PublicUser[] | null;
}

/** Who belongs to a room and who is in it now, ranked by this week's focus. */
@Injectable()
export class RoomMembersService {
  constructor(
    private readonly directory: RoomDirectory,
    private readonly desks: DeskStore,
    private readonly rooms: RoomsRepository,
    private readonly users: UsersRepository,
    private readonly sessions: FocusSessionsRepository,
  ) {}

  async list(
    viewer: ReaderSession,
    roomId: string,
    now: number,
  ): Promise<RoomMembers> {
    if (viewer.roomId !== roomId)
      ProtocolError.throw('NOT_IN_ROOM', 'Open the room first');
    const isHall = RoomDirectory.isHallId(roomId);
    const [presentIds, desks, memberIds, room] = await Promise.all([
      this.directory.presentUserIds(roomId, now),
      this.desks.list(roomId),
      isHall ? Promise.resolve([]) : this.rooms.memberIds(roomId),
      isHall ? Promise.resolve(null) : this.rooms.findById(roomId),
    ]);

    const deskByUser = new Map(desks.map((desk) => [desk.userId, desk]));
    const present = new Set(presentIds);
    const members = new Set(memberIds);
    const ids = [
      ...new Set([...deskByUser.keys(), ...presentIds, ...memberIds]),
    ];
    const [users, recorded] = await Promise.all([
      this.users.findMany(ids),
      this.sessions.focusByUser(
        roomId,
        ids,
        new Date(now - LEADERBOARD_WINDOW_MS),
      ),
    ]);

    const people = ids.flatMap((id): RoomPerson[] => {
      const user = users.get(id);
      if (!user) return [];
      const desk = deskByUser.get(id);
      const reading = desk ? readTimer(desk.timer, now) : null;
      const { statsVisible, ...publicUser } = user;
      return [
        {
          user: publicUser,
          role:
            id === room?.ownerId
              ? 'OWNER'
              : members.has(id)
                ? 'MEMBER'
                : 'GUEST',
          isHere: present.has(id) || desk !== undefined,
          desk:
            desk && reading
              ? {
                  deskId: desk.deskId,
                  category: desk.category,
                  resting: reading.phase === 'BREAK',
                }
              : null,
          weekFocusMs:
            statsVisible || id === viewer.user.id
              ? (recorded.get(id) ?? 0) + (reading?.focusedMs ?? 0)
              : null,
        },
      ];
    });

    people.sort(
      (a, b) =>
        (b.weekFocusMs ?? -1) - (a.weekFocusMs ?? -1) ||
        a.user.displayName.localeCompare(b.user.displayName, 'tr'),
    );
    const banned =
      room && room.ownerId === viewer.user.id
        ? await this.rooms.banned(roomId)
        : null;
    return { people, banned };
  }
}
