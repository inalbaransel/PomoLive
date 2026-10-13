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
