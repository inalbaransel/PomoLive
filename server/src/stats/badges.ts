import { DAY_MS, localDateKey } from '../library/local-day.js';

export type BadgeId =
  | 'first_session'
  | 'marathon'
  | 'ten_hours'
  | 'hundred_hours'
  | 'fifty_sessions'
  | 'streak_7'
  | 'streak_30'
  | 'early_bird'
  | 'night_owl'
  | 'all_rounder';

export interface Badge {
  id: BadgeId;
  /** 0…1; earned at 1. */
  progress: number;
  earned: boolean;
}

export interface BadgeSession {
  startedAt: Date;
  focusedMs: number;
  categoryKey: string;
}

const HOUR_MS = 3_600_000;

/** Local hour (0–23) of an instant in the reader's time zone. */
function localHour(at: number, timeZone: string): number {
  return Number(
    new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour: 'numeric',
      hourCycle: 'h23',
    }).format(at),
  );
}

/** Longest run of consecutive days with focus. */
function longestStreak(dayKeys: Set<string>): number {
  const days = [...dayKeys]
    .map((key) => Date.parse(`${key}T12:00:00Z`))
    .sort((a, b) => a - b);
  let best = 0;
  let run = 0;
  for (let index = 0; index < days.length; index++) {
    run =
      index > 0 && Math.round((days[index] - days[index - 1]) / DAY_MS) === 1
        ? run + 1
        : 1;
    best = Math.max(best, run);
  }
  return best;
}

/**
 * Milestones earned from recorded sessions. Computed on the server from history, so they
 * cannot be faked and look the same on every profile.
 */
export function computeBadges(
  sessions: BadgeSession[],
  totalMs: number,
  sessionCount: number,
  timeZone: string,
  now: number,
): Badge[] {
  const streak = longestStreak(
    new Set(
      sessions.map((session) =>
        localDateKey(session.startedAt.getTime(), timeZone),
      ),
    ),
  );
  const longest = Math.max(0, ...sessions.map((session) => session.focusedMs));
  const hours = sessions.map((session) =>
    localHour(session.startedAt.getTime(), timeZone),
  );
  const earlyCount = hours.filter((hour) => hour >= 5 && hour < 8).length;
  const lateCount = hours.filter((hour) => hour >= 23 || hour < 4).length;
  const recentCategories = new Set(
    sessions
      .filter((session) => session.startedAt.getTime() >= now - 30 * DAY_MS)
      .map((session) => session.categoryKey),
  ).size;

  const ratio = (value: number, goal: number) => Math.min(1, value / goal);
  const progress: Record<BadgeId, number> = {
    first_session: ratio(sessionCount, 1),
    marathon: ratio(longest, 2 * HOUR_MS),
    ten_hours: ratio(totalMs, 10 * HOUR_MS),
    hundred_hours: ratio(totalMs, 100 * HOUR_MS),
    fifty_sessions: ratio(sessionCount, 50),
    streak_7: ratio(streak, 7),
    streak_30: ratio(streak, 30),
    early_bird: ratio(earlyCount, 5),
    night_owl: ratio(lateCount, 5),
    all_rounder: ratio(recentCategories, 4),
  };
  return (Object.keys(progress) as BadgeId[]).map((id) => ({
    id,
    progress: progress[id],
    earned: progress[id] >= 1,
  }));
}
