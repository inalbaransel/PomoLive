/**
 * Each reader's own timer. Pure functions of stored anchors, so the server never ticks and every
 * device (and the iOS `DeskTimer`) computes the same phase from the same record, even while the
 * phone is locked. Keep in sync with `ios/PomoLive/Hall/DeskTimer.swift`.
 */
export type TimerMode = 'POMODORO' | 'STOPWATCH';
export type TimerPhase = 'FOCUS' | 'BREAK';

export interface PomodoroTimer {
  mode: 'POMODORO';
  focusMinutes: number;
  breakMinutes: number;
  /** Start of the current focus/break cycle sequence. */
  anchorAt: number;
  /** Focus banked before `anchorAt`; may be negative after a manual break (see `startBreak`). */
  bankedFocusMs: number;
}

export interface StopwatchTimer {
  mode: 'STOPWATCH';
  running: boolean;
  /** When `running` last changed. */
  since: number;
  bankedFocusMs: number;
}

export type DeskTimer = PomodoroTimer | StopwatchTimer;

export interface TimerReading {
  phase: TimerPhase;
  phaseStartedAt: number;
  /** `null` for a stopwatch, which has no planned end. */
  phaseEndsAt: number | null;
  focusedMs: number;
}

const MINUTE = 60_000;

export function readTimer(timer: DeskTimer, now: number): TimerReading {
  if (timer.mode === 'STOPWATCH') {
    return {
      phase: timer.running ? 'FOCUS' : 'BREAK',
      phaseStartedAt: timer.since,
      phaseEndsAt: null,
      focusedMs:
        timer.bankedFocusMs +
        (timer.running ? Math.max(0, now - timer.since) : 0),
    };
  }

  const focusMs = timer.focusMinutes * MINUTE;
  const periodMs = focusMs + timer.breakMinutes * MINUTE;
  const elapsed = Math.max(0, now - timer.anchorAt);
  const cycles = Math.floor(elapsed / periodMs);
  const withinCycle = elapsed - cycles * periodMs;
  const cycleStart = timer.anchorAt + cycles * periodMs;
  const inFocus = withinCycle < focusMs;
  return {
    phase: inFocus ? 'FOCUS' : 'BREAK',
    phaseStartedAt: inFocus ? cycleStart : cycleStart + focusMs,
    phaseEndsAt: inFocus ? cycleStart + focusMs : cycleStart + periodMs,
    focusedMs:
      timer.bankedFocusMs + cycles * focusMs + Math.min(withinCycle, focusMs),
  };
}

/** Pauses a stopwatch, or jumps a pomodoro straight into its break. No-op when already on break. */
export function startBreak(timer: DeskTimer, now: number): DeskTimer {
  const reading = readTimer(timer, now);
  if (reading.phase === 'BREAK') return timer;
  if (timer.mode === 'STOPWATCH') {
    return {
      ...timer,
      running: false,
      since: now,
      bankedFocusMs: reading.focusedMs,
    };
  }
  // Re-anchor so a break begins now; the new segment will count one full focus block we didn't do.
  const focusMs = timer.focusMinutes * MINUTE;
  return {
    ...timer,
    anchorAt: now - focusMs,
    bankedFocusMs: reading.focusedMs - focusMs,
  };
}

/** Resumes a stopwatch, or skips the rest of a pomodoro break. No-op when already focusing. */
export function resumeFocus(timer: DeskTimer, now: number): DeskTimer {
  const reading = readTimer(timer, now);
  if (reading.phase === 'FOCUS') return timer;
  if (timer.mode === 'STOPWATCH')
    return { ...timer, running: true, since: now };
  return { ...timer, anchorAt: now, bankedFocusMs: reading.focusedMs };
}
