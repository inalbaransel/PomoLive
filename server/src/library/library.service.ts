import { Injectable, Logger } from '@nestjs/common';
import { CategoriesRepository } from '../categories/categories.repository.js';
import { AppConfig } from '../config/app-config.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { RoomsRepository } from '../rooms/rooms.repository.js';
import { ProfileChanges, UserProfile } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';
import { ActivityFeed } from './activity-feed.js';
import { DeskStore, LeaseRef } from './desk-store.js';
import { DeskTimer, readTimer, resumeFocus, startBreak } from './desk-timer.js';
import { FocusSessionsRepository } from './focus-sessions.repository.js';
import {
  findLayoutDesk,
  LibraryLayout,
  getLayoutForTheme,
} from './layout/library-layout.js';
import { DeskRecord, RoomState, VacateReason } from './library.types.js';
import { startOfLocalDay } from './local-day.js';
import { RoomDirectory, RoomIdentity } from './room-directory.js';

/** Per-connection state the gateway owns and passes into every command. */
export interface ReaderSession {
  user: UserProfile;
  timeZone: string;
  /** The room this connection is looking at; independent of where the reader holds a desk. */
  roomId: string | null;
}

export interface RoomSnapshot {
  room: RoomState;
  layout: LibraryLayout;
  desks: DeskRecord[];
  serverTime: number;
}

export type TimerSetup =
  | { mode: 'POMODORO'; focusMinutes: number; breakMinutes: number }
  | { mode: 'STOPWATCH' };

export interface SitRequest {
  deskId: string;
  timer: TimerSetup;
  categoryKey: string;
  note?: string;
}

/** What happens inside a room: who looks at it, who sits where, and each desk's timer. */
@Injectable()
export class LibraryService {
  private readonly logger = new Logger(LibraryService.name);

  constructor(
    private readonly config: AppConfig,
    private readonly rooms: RoomDirectory,
    private readonly desks: DeskStore,
    private readonly sessions: FocusSessionsRepository,
    private readonly categories: CategoriesRepository,
    private readonly roomCatalogue: RoomsRepository,
    private readonly users: UsersRepository,
    private readonly feed: ActivityFeed,
    private readonly bus: RoomEventBus,
  ) {}

  async enter(
    session: ReaderSession,
    room: RoomIdentity,
  ): Promise<RoomSnapshot> {
    const now = Date.now();
    if (session.roomId && session.roomId !== room.id)
      await this.stopViewing(session);
    await this.rooms.ensureLive(room, now);

    session.roomId = room.id;
    await this.rooms.touchPresence(room.id, session.user.id, now);
    await this.publishPresence(room.id);
    return this.snapshot(room.id);
  }

  /** Stops looking at the room. A desk held there stays taken: the timer keeps running. */
  async stopViewing(session: ReaderSession): Promise<void> {
    const roomId = session.roomId;
    if (!roomId) return;
    session.roomId = null;
    await this.rooms.removePresence(roomId, session.user.id);
    await this.publishPresence(roomId);
  }

  async sit(session: ReaderSession, request: SitRequest): Promise<DeskRecord> {
    const roomId =
      session.roomId ?? ProtocolError.throw('NOT_IN_ROOM', 'Join a room first');
    const layoutDesk =
      findLayoutDesk(request.deskId) ??
      ProtocolError.throw('DESK_NOT_FOUND', `Unknown desk ${request.deskId}`);
    const category = await this.categories.resolve(
      session.user.id,
      request.categoryKey,
    );

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
      category,
      note: request.note || null,
      timer: LibraryService.startTimer(request.timer, now),
      startedAt: now,
      sessionNumber: sessionsToday + 1,
      leaseExpiresAt: now + this.config.foregroundLeaseMs,
    };

    switch (await this.desks.claim(roomId, desk)) {
      case 'OK':
        if (!RoomDirectory.isHallId(roomId)) {
          await this.roomCatalogue.touchMembership(session.user.id, roomId);
        }
        await this.bus.publish(roomId, ServerEvent.deskOccupied, { desk });
        await this.feed.started(
          await this.rooms.roomState(roomId, now),
          desk,
          now,
        );
        return desk;
      case 'DESK_TAKEN':
        return ProtocolError.throw(
          'DESK_TAKEN',
          'Someone just sat at this desk',
        );
      case 'ROOM_NOT_FOUND':
        return ProtocolError.throw('ROOM_NOT_FOUND', 'This room has closed');
      case 'ALREADY_SEATED':
        return ProtocolError.throw(
          'DESK_TAKEN',
          'You sat down somewhere else in the meantime',
        );
    }
  }

  async stand(session: ReaderSession): Promise<void> {
    await this.vacate(await this.requireSeat(session.user.id), 'STOOD_UP');
  }

  /** `BREAK` pauses a stopwatch or starts a pomodoro break now; `RESUME` resumes or skips the break. */
  async changeTimer(
    session: ReaderSession,
    action: 'BREAK' | 'RESUME',
  ): Promise<DeskRecord> {
    const ref = await this.requireSeat(session.user.id);
    const desk =
      (await this.desks.get(ref)) ??
      ProtocolError.throw('NOT_SEATED', 'You are not at a desk');
    const now = Date.now();
    const timer =
      action === 'BREAK'
        ? startBreak(desk.timer, now)
        : resumeFocus(desk.timer, now);
    if (timer === desk.timer) return desk;
    return this.patchAndPublish(ref, { timer });
  }

  /**
   * Keeps presence and the desk lease alive. Before the app is suspended the client sends
   * `background: true`, which stretches the lease so a locked phone does not lose its desk.
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
    if (!desk) {
      // The seat pointer names a desk the reader no longer holds; the lease cannot be renewed.
      this.logger.warn(
        `Heartbeat could not renew ${session.user.id} at ${seat.roomId}/${seat.deskId}`,
      );
    }
    return { serverTime: now, leaseExpiresAt: desk?.leaseExpiresAt ?? null };
  }

  /** The reader's own desk and its room wherever it is, so a client can show the timer outside the room. */
  async mySeat(
    userId: string,
  ): Promise<{ desk: DeskRecord | null; room: RoomState | null }> {
    const seat = await this.desks.seatOf(userId);
    if (!seat) return { desk: null, room: null };
    const [desk, room] = await Promise.all([
      this.desks.get(seat),
      this.rooms.roomState(seat.roomId, Date.now()),
    ]);
    return { desk, room };
  }

  async updateProfile(
    session: ReaderSession,
    changes: ProfileChanges,
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

  /** Ends every session in the room and tells viewers it is gone. */
  async closeRoom(roomId: string): Promise<void> {
    for (const desk of await this.desks.list(roomId)) {
      await this.vacate(
        { roomId, deskId: desk.deskId, userId: desk.userId },
        'ROOM_CLOSED',
      );
    }
    await this.bus.publish(roomId, ServerEvent.roomClosed, {});
    await this.rooms.close(roomId);
  }

  /**
   * Takes a reader out of a room the owner removed them from: their desk there is freed and
   * everyone, including the reader wherever they are, learns about it.
   */
  async removeReader(roomId: string, userId: string): Promise<void> {
    const seat = await this.desks.seatOf(userId);
    if (seat?.roomId === roomId)
      await this.vacate({ ...seat, userId }, 'REMOVED');
    await this.rooms.removePresence(roomId, userId);
    await this.bus.publish(roomId, ServerEvent.memberRemoved, { userId });
    await this.publishPresence(roomId);
  }

  /** Pushes a room's new name, icon or visibility to everyone looking at it. */
  async refreshRoom(room: RoomIdentity): Promise<void> {
    await this.rooms.updateIdentity(room);
    const state = await this.rooms.roomState(room.id, Date.now());
    if (state)
      await this.bus.publish(room.id, ServerEvent.roomUpdated, { room: state });
  }

  async standUp(userId: string): Promise<void> {
    const seat = await this.desks.seatOf(userId);
    if (seat) await this.vacate({ ...seat, userId }, 'STOOD_UP');
  }

  private async vacate(
    ref: LeaseRef,
    reason: VacateReason,
    expiredBefore = 0,
  ): Promise<void> {
    const desk = await this.desks.release(ref, expiredBefore);
    if (!desk) return;
    const now = Date.now();
    const room = await this.rooms.roomState(ref.roomId, now);
    await this.sessions.record(
      { id: ref.roomId, name: room?.name ?? 'Piksel Salon' },
      desk,
      now,
      reason,
    );
    await this.bus.publish(ref.roomId, ServerEvent.deskVacated, {
      deskId: desk.deskId,
      userId: desk.userId,
      reason,
    });
    await this.feed.finished(
      room,
      desk,
      readTimer(desk.timer, now).focusedMs,
      now,
    );
  }

  /** The occupied desk `deskId` in the room this connection is looking at. */
  async occupiedDesk(
    session: ReaderSession,
    deskId: string,
  ): Promise<DeskRecord> {
    const roomId =
      session.roomId ?? ProtocolError.throw('NOT_IN_ROOM', 'Join a room first');
    return (
      (await this.desks.get({ roomId, deskId })) ??
      ProtocolError.throw('DESK_NOT_FOUND', 'Nobody sits at this desk')
    );
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
    if (!room) ProtocolError.throw('ROOM_NOT_FOUND', 'This room has closed');
    const layout = getLayoutForTheme(room.theme);
    return { room, layout, desks, serverTime: now };
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

  private async requireSeat(userId: string): Promise<LeaseRef> {
    const seat =
      (await this.desks.seatOf(userId)) ??
      ProtocolError.throw('NOT_SEATED', 'You are not at a desk');
    return { ...seat, userId };
  }

  private static startTimer(setup: TimerSetup, now: number): DeskTimer {
    return setup.mode === 'POMODORO'
      ? { ...setup, anchorAt: now, bankedFocusMs: 0 }
      : { mode: 'STOPWATCH', running: true, since: now, bankedFocusMs: 0 };
  }
}
