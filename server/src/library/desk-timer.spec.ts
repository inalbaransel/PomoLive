import {
  PomodoroTimer,
  readTimer,
  resumeFocus,
  startBreak,
  StopwatchTimer,
} from './desk-timer.js';

const MINUTE = 60_000;
const t0 = 1_776_150_000_000;

const pomodoro: PomodoroTimer = {
  mode: 'POMODORO',
  focusMinutes: 25,
  breakMinutes: 5,
  anchorAt: t0,
  bankedFocusMs: 0,
};
const stopwatch: StopwatchTimer = {
  mode: 'STOPWATCH',
  running: true,
  since: t0,
  bankedFocusMs: 0,
};

describe('pomodoro', () => {
  it('cycles focus and break and counts only focus', () => {
    expect(readTimer(pomodoro, t0 + 10 * MINUTE)).toEqual({
      phase: 'FOCUS',
      phaseStartedAt: t0,
      phaseEndsAt: t0 + 25 * MINUTE,
      focusedMs: 10 * MINUTE,
    });
    expect(readTimer(pomodoro, t0 + 27 * MINUTE)).toMatchObject({
      phase: 'BREAK',
      phaseEndsAt: t0 + 30 * MINUTE,
      focusedMs: 25 * MINUTE,
    });
    expect(readTimer(pomodoro, t0 + 57 * MINUTE)).toMatchObject({
      phase: 'BREAK',
      focusedMs: 50 * MINUTE,
    });
    expect(readTimer(pomodoro, t0 + 65 * MINUTE)).toMatchObject({
      phase: 'FOCUS',
      focusedMs: 55 * MINUTE,
    });
  });

  it('starts a break early without inventing focus time', () => {
    const onBreak = startBreak(pomodoro, t0 + 10 * MINUTE);
    expect(readTimer(onBreak, t0 + 10 * MINUTE)).toMatchObject({
      phase: 'BREAK',
      phaseEndsAt: t0 + 15 * MINUTE,
      focusedMs: 10 * MINUTE,
    });
    expect(readTimer(onBreak, t0 + 20 * MINUTE)).toMatchObject({
      phase: 'FOCUS',
      focusedMs: 15 * MINUTE,
    });
  });

  it('skips the rest of a break', () => {
    const resumed = resumeFocus(pomodoro, t0 + 27 * MINUTE);
    expect(readTimer(resumed, t0 + 27 * MINUTE)).toMatchObject({
      phase: 'FOCUS',
      phaseEndsAt: t0 + 52 * MINUTE,
      focusedMs: 25 * MINUTE,
    });
  });

  it('ignores redundant transitions', () => {
    expect(resumeFocus(pomodoro, t0 + MINUTE)).toBe(pomodoro);
    const onBreak = startBreak(pomodoro, t0 + MINUTE);
    expect(startBreak(onBreak, t0 + 2 * MINUTE)).toBe(onBreak);
  });
});

describe('stopwatch', () => {
  it('counts running time and freezes while paused', () => {
    const paused = startBreak(stopwatch, t0 + 30 * MINUTE);
    expect(readTimer(paused, t0 + 45 * MINUTE)).toEqual({
      phase: 'BREAK',
      phaseStartedAt: t0 + 30 * MINUTE,
      phaseEndsAt: null,
      focusedMs: 30 * MINUTE,
    });
    const resumed = resumeFocus(paused, t0 + 45 * MINUTE);
    expect(readTimer(resumed, t0 + 50 * MINUTE).focusedMs).toBe(35 * MINUTE);
  });
});
