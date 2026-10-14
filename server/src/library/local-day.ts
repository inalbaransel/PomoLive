const DAY_MS = 24 * 60 * 60_000;
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/** Midnight of `now`'s calendar day in `timeZone`. */
export function startOfLocalDay(now: number, timeZone: string): Date {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
  }).formatToParts(now);
  const field = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((part) => part.type === type)?.value ?? 0);
  const elapsedToday =
    ((field('hour') * 60 + field('minute')) * 60 + field('second')) * 1000 +
    (now % 1000);
  return new Date(now - elapsedToday);
}

/** Monday 00:00 of `now`'s week in `timeZone`. */
export function startOfLocalWeek(now: number, timeZone: string): Date {
  const weekday = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'short',
  }).format(now);
  return new Date(
    startOfLocalDay(now, timeZone).getTime() -
      WEEKDAYS.indexOf(weekday) * DAY_MS,
  );
}

/** `YYYY-MM-DD` of `at` in `timeZone`. */
export function localDateKey(at: number, timeZone: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

export { DAY_MS };
