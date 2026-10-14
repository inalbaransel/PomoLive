import {
  localDateKey,
  startOfLocalDay,
  startOfLocalWeek,
} from './local-day.js';

describe('local days', () => {
  const now = Date.UTC(2026, 9, 14, 21, 30, 15, 250); // Wednesday 14 Oct, 00:30 on Thursday in Istanbul

  it('returns midnight in the given time zone', () => {
    expect(startOfLocalDay(now, 'UTC').toISOString()).toBe(
      '2026-10-14T00:00:00.000Z',
    );
    expect(startOfLocalDay(now, 'Europe/Istanbul').toISOString()).toBe(
      '2026-10-14T21:00:00.000Z',
    );
  });

  it('returns Monday midnight of the local week', () => {
    expect(startOfLocalWeek(now, 'UTC').toISOString()).toBe(
      '2026-10-12T00:00:00.000Z',
    );
    expect(startOfLocalWeek(now, 'Europe/Istanbul').toISOString()).toBe(
      '2026-10-11T21:00:00.000Z',
    );
  });

  it('formats local calendar dates', () => {
    expect(localDateKey(now, 'UTC')).toBe('2026-10-14');
    expect(localDateKey(now, 'Europe/Istanbul')).toBe('2026-10-15');
  });
});
