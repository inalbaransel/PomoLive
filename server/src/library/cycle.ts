import { CyclePhase } from './library.types.js';

const MINUTE = 60_000;

export function cyclePhaseAt(
  anchorAt: number,
  focusMinutes: number,
  breakMinutes: number,
  now: number,
): { phase: CyclePhase; endsAt: number } {
  const focusMs = focusMinutes * MINUTE;
  const periodMs = focusMs + breakMinutes * MINUTE;
  const elapsed = (((now - anchorAt) % periodMs) + periodMs) % periodMs;
  const periodStart = now - elapsed;
  return elapsed < focusMs
    ? { phase: 'FOCUS', endsAt: periodStart + focusMs }
    : { phase: 'BREAK', endsAt: periodStart + periodMs };
}
