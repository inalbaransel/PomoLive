import { CategoryInfo } from '../categories/built-in-categories.js';
import { DeskTimer } from './desk-timer.js';

export type RoomKind = 'HALL' | 'PUBLIC' | 'PRIVATE';
export type VacateReason = 'STOOD_UP' | 'LEASE_EXPIRED' | 'ROOM_CLOSED';

/** One occupied desk, stored as JSON in `room:{roomId}:desks` and sent over the wire as-is. */
export interface DeskRecord {
  deskId: string;
  tileX: number;
  tileY: number;
  userId: string;
  userName: string;
  avatarSpriteId: string;
  category: CategoryInfo;
  note: string | null;
  timer: DeskTimer;
  /** When the reader sat down (ms epoch). */
  startedAt: number;
  /** 1-based count of today's sessions for this reader, shown as "3. Seans". */
  sessionNumber: number;
  leaseExpiresAt: number;
}

export interface RoomState {
  id: string;
  kind: RoomKind;
  name: string;
  emoji: string;
  /** Share code of a user-created room; `null` for system halls. */
  code: string | null;
  ownerId: string | null;
  capacity: number;
  occupiedCount: number;
  presenceCount: number;
}
