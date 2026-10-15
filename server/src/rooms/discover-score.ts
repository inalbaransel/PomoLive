/**
 * How high a public room ranks in Keşfet. Live activity dominates; past focus keeps good rooms
 * visible between sessions but fades (3-day half-life) so old hits do not squat the list forever;
 * new rooms get a short boost so they can be found at all; full rooms sink because nobody can sit.
 */
export interface RoomSignals {
  occupiedCount: number;
  presenceCount: number;
  capacity: number;
  /** Focus hours from the last 7 days, each session weighted by 0.5^(age / 3 days). */
  decayedFocusHours: number;
  /** Distinct readers who focused here in the last 7 days. */
  weeklyReaders: number;
  memberCount: number;
  ageHours: number;
}

export const FOCUS_HALF_LIFE_MS = 3 * 24 * 60 * 60_000;
const NEW_ROOM_WINDOW_HOURS = 48;

export function discoverScore(room: RoomSignals): number {
  const live = 3 * room.occupiedCount + room.presenceCount;
  const popularity =
    4 * Math.log1p(room.decayedFocusHours) + 3 * Math.log1p(room.weeklyReaders);
  const community = 2 * Math.log1p(room.memberCount);
  const freshness =
    room.ageHours < NEW_ROOM_WINDOW_HOURS
      ? 3 * (1 - room.ageHours / NEW_ROOM_WINDOW_HOURS)
      : 0;
  const full = room.occupiedCount >= room.capacity ? -10 : 0;
  return 1.5 * live + popularity + community + freshness + full;
}

/** Weight of a session that started `ageMs` ago. */
export function decay(ageMs: number): number {
  return Math.pow(0.5, Math.max(0, ageMs) / FOCUS_HALF_LIFE_MS);
}
