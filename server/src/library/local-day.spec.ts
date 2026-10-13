import { startOfLocalDay } from './local-day.js';

describe('startOfLocalDay', () => {
  it('returns midnight in the given time zone', () => {
    const now = Date.UTC(2026, 9, 13, 21, 30, 15, 250);
    expect(startOfLocalDay(now, 'UTC').toISOString()).toBe(
      '2026-10-13T00:00:00.000Z',
    );
    expect(startOfLocalDay(now, 'Europe/Istanbul').toISOString()).toBe(
      '2026-10-13T21:00:00.000Z',
    );
  });
});
