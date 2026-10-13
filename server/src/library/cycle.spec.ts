import { cyclePhaseAt } from './cycle.js';

const MINUTE = 60_000;
const anchor = 1_776_150_000_000;

describe('cyclePhaseAt', () => {
  it('is in focus right after the anchor', () => {
    expect(cyclePhaseAt(anchor, 25, 5, anchor + MINUTE)).toEqual({ phase: 'FOCUS', endsAt: anchor + 25 * MINUTE });
  });

  it('switches to break once focus time is over', () => {
    expect(cyclePhaseAt(anchor, 25, 5, anchor + 26 * MINUTE)).toEqual({ phase: 'BREAK', endsAt: anchor + 30 * MINUTE });
  });

  it('repeats every period, also before the anchor', () => {
    expect(cyclePhaseAt(anchor, 25, 5, anchor + 61 * MINUTE).phase).toBe('FOCUS');
    expect(cyclePhaseAt(anchor, 25, 5, anchor - 2 * MINUTE)).toEqual({ phase: 'BREAK', endsAt: anchor });
  });
});
