export type DeskStatus = 'FOCUS' | 'BREAK';
export type RoomType = 'PUBLIC' | 'PRIVATE';
export type CyclePhase = 'FOCUS' | 'BREAK';
export type VacateReason = 'STOOD_UP' | 'LEASE_EXPIRED';

/** One occupied desk, stored as JSON in `room:{roomId}:desks` and sent over the wire as-is. */
export interface DeskRecord {
  deskId: string;
  tileX: number;
  tileY: number;
  userId: string;
  userName: string;
  avatarSpriteId: string;
  taskLabel: string;
  status: DeskStatus;
  /** When the reader sat down (ms epoch). */
  startedAt: number;
  /** When `status` last changed; elapsed time for the overhead badge is measured from here. */
  statusSince: number;
  /** Focus time banked before `statusSince`. */
  focusAccumulatedMs: number;
  /** 1-based count of today's sessions for this reader, shown as "3. Seans". */
  sessionNumber: number;
  leaseExpiresAt: number;
}

/**
 * Room-wide pomodoro rhythm, derived from `cycleAnchorAt` so neither server nor client needs a ticker:
 * every device computes the same phase from the same anchor.
 */
export interface RoomState {
  id: string;
  type: RoomType;
  code: string | null;
  capacity: number;
  occupiedCount: number;
  presenceCount: number;
  focusMinutes: number;
  breakMinutes: number;
  cycleAnchorAt: number;
  cyclePhase: CyclePhase;
  cycleEndsAt: number;
}
