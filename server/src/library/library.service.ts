import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { UserProfile } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';
import { DeskStore, LeaseRef } from './desk-store.js';
import { FocusSessionsRepository } from './focus-sessions.repository.js';
import {
  findLayoutDesk,
  LIBRARY_LAYOUT,
  LibraryLayout,
} from './layout/library-layout.js';
import {
  DeskRecord,
  DeskStatus,
  RoomState,
  VacateReason,
} from './library.types.js';
import { startOfLocalDay } from './local-day.js';
import { RoomDirectory } from './room-directory.js';

/** Per-connection state the gateway owns and passes into every command. */
export interface ReaderSession {
  user: UserProfile;
  timeZone: string;
  roomId: string | null;
}

export interface RoomSnapshot {
  room: RoomState;
  layout: LibraryLayout;
  desks: DeskRecord[];
  serverTime: number;
}

@Injectable()
export class LibraryService {
  constructor(
    private readonly config: AppConfig,
    private readonly rooms: RoomDirectory,
    private readonly desks: DeskStore,
    private readonly sessions: FocusSessionsRepository,
    private readonly users: UsersRepository,
    private readonly bus: RoomEventBus,
  ) {}

  /**
   * Enters a hall. Without a code the reader returns to the hall where they still hold a desk,
   * otherwise they are routed to a public hall with room to spare.
   */
  async join(
    session: ReaderSession,
    code: string | undefined,
  ): Promise<RoomSnapshot> {
    const now = Date.now();
    const roomId = code
      ? await this.privateRoomId(code)
      : await this.resumeOrAssign(session.user.id, now);
    if (session.roomId && session.roomId !== roomId) await this.leave(session);

    session.roomId = roomId;
    await this.rooms.touchPresence(roomId, session.user.id, now);
    await this.publishPresence(roomId);
    return this.snapshot(roomId);
  }

  async createPrivateRoom(session: ReaderSession): Promise<RoomSnapshot> {
    const { code } = await this.rooms.createPrivateRoom(Date.now());
    return this.join(session, code);
  }

  /** Stops viewing the hall. A desk held in that hall is given up too. */
  async leave(session: ReaderSession): Promise<void> {
    const roomId = session.roomId;
    if (!roomId) return;
    const seat = await this.desks.seatOf(session.user.id);
    if (seat?.roomId === roomId)
      await this.vacate({ ...seat, userId: session.user.id }, 'STOOD_UP');

    session.roomId = null;
    await this.rooms.removePresence(roomId, session.user.id);
    await this.publishPresence(roomId);
  }

  /** Socket closed without an explicit leave: keep the desk (its lease decides), drop presence only. */
  async disconnect(session: ReaderSession): Promise<void> {
    if (!session.roomId) return;
    await this.rooms.removePresence(session.roomId, session.user.id);
    await this.publishPresence(session.roomId);
  }

  async sit(
    session: ReaderSession,
    deskId: string,
    taskLabel: string,
  ): Promise<DeskRecord> {
    const roomId = LibraryService.requireRoom(session);
    const layoutDesk =
      findLayoutDesk(deskId) ??
      ProtocolError.throw('DESK_NOT_FOUND', `Unknown desk ${deskId}`);

    const currentSeat = await this.desks.seatOf(session.user.id);
    if (currentSeat)
      await this.vacate(
        { ...currentSeat, userId: session.user.id },
        'STOOD_UP',
      );

    const now = Date.now();
    const sessionsToday = await this.sessions.countSince(
      session.user.id,
      startOfLocalDay(now, session.timeZone),
    );
    const desk: DeskRecord = {
      ...layoutDesk,
      userId: session.user.id,
      userName: session.user.displayName,
      avatarSpriteId: session.user.avatarSpriteId,
      taskLabel,
      status: 'FOCUS',
      startedAt: now,
      statusSince: now,
      focusAccumulatedMs: 0,
      sessionNumber: sessionsToday + 1,
      leaseExpiresAt: now + this.config.foregroundLeaseMs,
    };

    const outcome = await this.desks.claim(roomId, desk);
    switch (outcome) {
      case 'OK':
        await this.bus.publish(roomId, ServerEvent.deskOccupied, { desk });
        return desk;
      case 'DESK_TAKEN':
        return ProtocolError.throw(
          'DESK_TAKEN',
          'Someone just sat at this desk',
        );
      case 'ROOM_NOT_FOUND':
        return ProtocolError.throw('ROOM_NOT_FOUND', 'This hall has closed');
      case 'ALREADY_SEATED':
        return ProtocolError.throw(
          'DESK_TAKEN',
          'You sat down somewhere else in the meantime',
        );
    }
  }

  async stand(session: ReaderSession): Promise<void> {
    const seat =
      (await this.desks.seatOf(session.user.id)) ??
      ProtocolError.throw('NOT_SEATED', 'You are not at a desk');
    await this.vacate({ ...seat, userId: session.user.id }, 'STOOD_UP');
  }

  async setStatus(
    session: ReaderSession,
    status: DeskStatus,
  ): Promise<DeskRecord> {
    const ref = await this.requireSeat(session);
    const desk =
      (await this.desks.get(ref)) ??
      ProtocolError.throw('NOT_SEATED', 'You are not at a desk');
    if (desk.status === status) return desk;

    const now = Date.now();
    const bankedFocus = desk.status === 'FOCUS' ? now - desk.statusSince : 0;
    return this.patchAndPublish(ref, {
      status,
      statusSince: now,
      focusAccumulatedMs: desk.focusAccumulatedMs + bankedFocus,
    });
  }

  /**
   * Keeps presence and the desk lease alive. Before the app is suspended the client sends
   * `background: true`, which stretches the lease so a locked phone does not lose its chair.
   */
  async heartbeat(
    session: ReaderSession,
    background: boolean,
  ): Promise<{ serverTime: number; leaseExpiresAt: number | null }> {
    const now = Date.now();
    if (session.roomId && !background)
      await this.rooms.touchPresence(session.roomId, session.user.id, now);

    const seat = await this.desks.seatOf(session.user.id);
    if (!seat) return { serverTime: now, leaseExpiresAt: null };
    const leaseExpiresAt =
      now +
      (background
        ? this.config.backgroundLeaseMs
        : this.config.foregroundLeaseMs);
    const desk = await this.desks.patch(
      { ...seat, userId: session.user.id },
      { leaseExpiresAt },
    );
    return { serverTime: now, leaseExpiresAt: desk?.leaseExpiresAt ?? null };
  }

  async updateProfile(
    session: ReaderSession,
    changes: Partial<Omit<UserProfile, 'id'>>,
  ): Promise<UserProfile> {
    session.user = await this.users.update(session.user.id, changes);
    const seat = await this.desks.seatOf(session.user.id);
    if (seat) {
      await this.patchAndPublish(
        { ...seat, userId: session.user.id },
        {
          userName: session.user.displayName,
          avatarSpriteId: session.user.avatarSpriteId,
        },
      );
    }
    return session.user;
  }

  /** Called by the reaper. No-op if the reader renewed the lease after it was picked up. */
  async expireLease(ref: LeaseRef, now: number): Promise<void> {
    await this.vacate(ref, 'LEASE_EXPIRED', now);
  }

  private async vacate(
    ref: LeaseRef,
    reason: VacateReason,
    expiredBefore = 0,
  ): Promise<void> {
    const desk = await this.desks.release(ref, expiredBefore);
    if (!desk) return;
    await this.sessions.record(ref.roomId, desk, Date.now(), reason);
    await this.bus.publish(ref.roomId, ServerEvent.deskVacated, {
      deskId: desk.deskId,
      userId: desk.userId,
      reason,
    });
  }

  private async patchAndPublish(
    ref: LeaseRef,
    changes: Partial<DeskRecord>,
  ): Promise<DeskRecord> {
    const desk =
      (await this.desks.patch(ref, changes)) ??
      ProtocolError.throw('NOT_SEATED', 'You are not at a desk');
    await this.bus.publish(ref.roomId, ServerEvent.deskUpdated, { desk });
    return desk;
  }

  private async snapshot(roomId: string): Promise<RoomSnapshot> {
    const now = Date.now();
    const [room, desks] = await Promise.all([
      this.rooms.roomState(roomId, now),
      this.desks.list(roomId),
    ]);
    if (!room) ProtocolError.throw('ROOM_NOT_FOUND', 'This hall has closed');
    return { room, layout: LIBRARY_LAYOUT, desks, serverTime: now };
  }

  private async publishPresence(roomId: string): Promise<void> {
    const room = await this.rooms.roomState(roomId, Date.now());
    if (room) {
      await this.bus.publish(roomId, ServerEvent.presence, {
        presenceCount: room.presenceCount,
        occupiedCount: room.occupiedCount,
      });
    }
  }

  private async privateRoomId(code: string): Promise<string> {
    const roomId = RoomDirectory.privateRoomId(code);
    if (!(await this.rooms.exists(roomId)))
      ProtocolError.throw('ROOM_NOT_FOUND', `No hall with code ${code}`);
    return roomId;
  }

  private async resumeOrAssign(userId: string, now: number): Promise<string> {
    const seat = await this.desks.seatOf(userId);
    if (seat && (await this.rooms.exists(seat.roomId))) return seat.roomId;
    return this.rooms.assignPublicRoom(now);
  }

  private async requireSeat(session: ReaderSession): Promise<LeaseRef> {
    const seat =
      (await this.desks.seatOf(session.user.id)) ??
      ProtocolError.throw('NOT_SEATED', 'You are not at a desk');
    return { ...seat, userId: session.user.id };
  }

  private static requireRoom(session: ReaderSession): string {
    return (
      session.roomId ?? ProtocolError.throw('NOT_IN_ROOM', 'Join a hall first')
    );
  }
}
