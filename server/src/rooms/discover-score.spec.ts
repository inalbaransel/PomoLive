import {
  decay,
  discoverScore,
  FOCUS_HALF_LIFE_MS,
  RoomSignals,
} from './discover-score.js';

const quiet: RoomSignals = {
  occupiedCount: 0,
  presenceCount: 0,
  capacity: 30,
  decayedFocusHours: 0,
  weeklyReaders: 0,
  memberCount: 1,
  ageHours: 24 * 30,
};

describe('discoverScore', () => {
  it('ranks a room with people focusing now above a quiet one', () => {
    expect(discoverScore({ ...quiet, occupiedCount: 3 })).toBeGreaterThan(
      discoverScore(quiet),
    );
  });

  it('keeps a room that was busy this week above an idle one', () => {
    const busyWeek = { ...quiet, decayedFocusHours: 40, weeklyReaders: 12 };
    expect(discoverScore(busyWeek)).toBeGreaterThan(discoverScore(quiet));
  });

  it('lets live activity outweigh a large but quiet history', () => {
    const famousButEmpty = {
      ...quiet,
      decayedFocusHours: 200,
      weeklyReaders: 30,
      memberCount: 200,
    };
    const livelyNow = { ...quiet, occupiedCount: 10, presenceCount: 4 };
    expect(discoverScore(livelyNow)).toBeGreaterThan(
      discoverScore(famousButEmpty),
    );
  });

  it('boosts brand new rooms and fades the boost after two days', () => {
    expect(discoverScore({ ...quiet, ageHours: 1 })).toBeGreaterThan(
      discoverScore({ ...quiet, ageHours: 47 }),
    );
    expect(discoverScore({ ...quiet, ageHours: 49 })).toBe(
      discoverScore(quiet),
    );
  });

  it('sinks full rooms', () => {
    const almostFull = { ...quiet, occupiedCount: 29 };
    const full = { ...quiet, occupiedCount: 30 };
    expect(discoverScore(full)).toBeLessThan(discoverScore(almostFull));
  });
});

describe('decay', () => {
  it('halves every half-life', () => {
    expect(decay(0)).toBe(1);
    expect(decay(FOCUS_HALF_LIFE_MS)).toBeCloseTo(0.5);
    expect(decay(2 * FOCUS_HALF_LIFE_MS)).toBeCloseTo(0.25);
  });
});
