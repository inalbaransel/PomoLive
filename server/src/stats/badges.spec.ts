import { computeBadges } from './badges.js';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const now = Date.parse('2026-10-16T12:00:00Z');

describe('computeBadges', () => {
  it('starts with nothing earned', () => {
    const badges = computeBadges([], 0, 0, 'UTC', now);
    expect(badges.every((badge) => !badge.earned && badge.progress === 0)).toBe(
      true,
    );
  });

  it('earns milestones from history and reports partial progress', () => {
    const sessions = Array.from({ length: 8 }, (_, day) => ({
      // 06:00 UTC each day for the last 8 days, 90 minutes, rotating categories.
      startedAt: new Date(Date.parse('2026-10-09T06:00:00Z') + day * DAY),
      focusedMs: 90 * 60_000,
      categoryKey: ['study', 'software', 'reading', 'writing'][day % 4],
    }));
    sessions.push({
      startedAt: new Date(now - 2 * HOUR),
      focusedMs: 2.5 * HOUR,
      categoryKey: 'study',
    });
    const badges = Object.fromEntries(
      computeBadges(sessions, 14.5 * HOUR, 9, 'UTC', now).map((badge) => [
        badge.id,
        badge,
      ]),
    );
    expect(badges.first_session.earned).toBe(true);
    expect(badges.marathon.earned).toBe(true);
    expect(badges.ten_hours.earned).toBe(true);
    expect(badges.streak_7.earned).toBe(true);
    expect(badges.early_bird.earned).toBe(true);
    expect(badges.all_rounder.earned).toBe(true);
    expect(badges.night_owl.earned).toBe(false);
    expect(badges.streak_30.progress).toBeCloseTo(8 / 30);
    expect(badges.hundred_hours.progress).toBeCloseTo(0.145);
  });

  it('reads hours in the reader’s time zone', () => {
    // 21:30 UTC is 00:30 in Istanbul: a night-owl session there, not in UTC.
    const late = Array.from({ length: 5 }, (_, day) => ({
      startedAt: new Date(Date.parse('2026-10-10T21:30:00Z') + day * DAY),
      focusedMs: 30 * 60_000,
      categoryKey: 'study',
    }));
    const istanbul = computeBadges(late, 0, 5, 'Europe/Istanbul', now).find(
      (badge) => badge.id === 'night_owl',
    );
    const utc = computeBadges(late, 0, 5, 'UTC', now).find(
      (badge) => badge.id === 'night_owl',
    );
    expect(istanbul?.earned).toBe(true);
    expect(utc?.earned).toBe(false);
  });
});
