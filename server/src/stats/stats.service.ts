import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { PrismaService } from '../infra/prisma.service.js';
import { RedisService } from '../infra/redis.service.js';
import { RedisKeys } from '../library/redis-keys.js';
import { Badge, computeBadges } from './badges.js';
import {
  DAY_MS,
  localDateKey,
  startOfLocalDay,
  startOfLocalWeek,
} from '../library/local-day.js';

/** Short, so today's numbers stay fresh across midnight too. */
const SUMMARY_CACHE_SECONDS = 60;

export interface CategoryTotal extends CategoryInfo {
  ms: number;
}

export interface DayTotal {
  date: string;
  totalMs: number;
  byCategory: CategoryTotal[];
}

/** PomoLive Plus: the long view of a reader's focus. */
export interface StatsInsights {
  /** Every local day of the last year with focus, oldest first. */
  days: { date: string; ms: number }[];
  /** The last six calendar months (`YYYY-MM`), oldest first, each with its categories largest first. */
  months: { month: string; totalMs: number; categories: CategoryTotal[] }[];
  /** Local hour (0–23) with the most focus started in it over the year. */
  bestHour: number | null;
  /** Weekday (1 = Monday … 7 = Sunday) with the most focus over the year. */
  bestWeekday: number | null;
  averageSessionMs: number;
  longestSessionMs: number;
}

/** One row of the CSV export. */
export interface ExportedSession {
  startedAt: number;
  endedAt: number;
  focusedMs: number;
  category: string;
  roomName: string;
  mode: string;
  note: string | null;
}

const EXPORT_LIMIT = 20_000;
const INSIGHT_MONTHS = 6;

export interface StatsSummary {
  todayMs: number;
  weekMs: number;
  /** The whole previous local week, for "compared to last week". */
  lastWeekMs: number;
  totalMs: number;
  sessionCount: number;
  /** Consecutive days with focus, ending today (or yesterday if today has none yet). */
  streakDays: number;
  last7Days: DayTotal[];
  /** Last 30 days, largest first. */
  categories: CategoryTotal[];
  /** Days with recorded focus (last year); charts unlock once this reaches `requiredDays`. */
  activeDays: number;
  requiredDays: number;
  /** Milestones from the last year of history plus lifetime totals. */
  badges: Badge[];
}

export interface HistoryEntry {
  id: string;
  roomId: string;
  roomName: string;
  mode: 'POMODORO' | 'STOPWATCH';
  category: CategoryInfo;
  note: string | null;
  startedAt: number;
  endedAt: number;
  focusedMs: number;
}

const STREAK_LOOKBACK_DAYS = 366;
/** Charts and totals need focus on this many separate days before they mean anything. */
const REQUIRED_ACTIVE_DAYS = 2;

@Injectable()
export class StatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  /**
   * The summary is read far more often than it changes (Stats, Profile, other readers' profiles),
   * so it is cached per time zone until the reader's next recorded session or a minute passes.
   */
  async summary(userId: string, timeZone: string): Promise<StatsSummary> {
    const key = RedisKeys.statsSummary(userId);
    const cached = await this.redis.client.hget(key, timeZone);
    if (cached) return JSON.parse(cached) as StatsSummary;
    const summary = await this.compute(userId, timeZone, Date.now());
    await this.redis.client
      .multi()
      .hset(key, timeZone, JSON.stringify(summary))
      .expire(key, SUMMARY_CACHE_SECONDS)
      .exec();
    return summary;
  }

  private async compute(
    userId: string,
    timeZone: string,
    now: number,
  ): Promise<StatsSummary> {
    const [sessions, totals] = await Promise.all([
      this.prisma.focusSession.findMany({
        where: {
          userId,
          startedAt: { gte: new Date(now - STREAK_LOOKBACK_DAYS * DAY_MS) },
        },
        select: {
          startedAt: true,
          focusedMs: true,
          categoryKey: true,
          categoryName: true,
          categorySymbol: true,
          categoryColor: true,
        },
      }),
      this.prisma.focusSession.aggregate({
        where: { userId },
        _sum: { focusedMs: true },
        _count: true,
      }),
    ]);

    const todayStart = startOfLocalDay(now, timeZone).getTime();
    const weekStart = startOfLocalWeek(now, timeZone).getTime();
    const monthStart = todayStart - 29 * DAY_MS;
    const days = new Map<string, Map<string, CategoryTotal>>();
    const categories = new Map<string, CategoryTotal>();
    let todayMs = 0;
    let weekMs = 0;
    let lastWeekMs = 0;
    const lastWeekStart = startOfLocalWeek(
      weekStart - DAY_MS,
      timeZone,
    ).getTime();

    for (const session of sessions) {
      const at = session.startedAt.getTime();
      const category = {
        key: session.categoryKey,
        name: session.categoryName,
        symbol: session.categorySymbol,
        color: session.categoryColor,
      };
      if (at >= todayStart) todayMs += session.focusedMs;
      if (at >= weekStart) weekMs += session.focusedMs;
      else if (at >= lastWeekStart) lastWeekMs += session.focusedMs;
      if (at >= monthStart)
        StatsService.add(categories, category, session.focusedMs);
      const day = localDateKey(at, timeZone);
      StatsService.add(
        days.get(day) ?? days.set(day, new Map()).get(day)!,
        category,
        session.focusedMs,
      );
    }

    const last7Days = Array.from({ length: 7 }, (_, index) => {
      const date = localDateKey(
        todayStart - (6 - index) * DAY_MS + DAY_MS / 2,
        timeZone,
      );
      const byCategory = StatsService.sorted(days.get(date));
      return {
        date,
        totalMs: byCategory.reduce((sum, item) => sum + item.ms, 0),
        byCategory,
      };
    });

    return {
      todayMs,
      weekMs,
      lastWeekMs,
      totalMs: totals._sum.focusedMs ?? 0,
      sessionCount: totals._count,
      streakDays: StatsService.streak(
        new Set(days.keys()),
        todayStart,
        timeZone,
      ),
      last7Days,
      categories: StatsService.sorted(categories),
      activeDays: days.size,
      requiredDays: REQUIRED_ACTIVE_DAYS,
      badges: computeBadges(
        sessions,
        totals._sum.focusedMs ?? 0,
        totals._count,
        timeZone,
        now,
      ),
    };
  }

  /** Newest first; pass the last entry's `startedAt` as `before` to page further back. */
  async insights(
    userId: string,
    timeZone: string,
    now = Date.now(),
  ): Promise<StatsInsights> {
    const sessions = await this.prisma.focusSession.findMany({
      where: {
        userId,
        startedAt: { gte: new Date(now - STREAK_LOOKBACK_DAYS * DAY_MS) },
      },
      orderBy: { startedAt: 'asc' },
      select: {
        startedAt: true,
        focusedMs: true,
        categoryKey: true,
        categoryName: true,
        categorySymbol: true,
        categoryColor: true,
      },
    });
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour: 'numeric',
      hourCycle: 'h23',
      weekday: 'short',
    });
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const days = new Map<string, number>();
    const months = new Map<string, Map<string, CategoryTotal>>();
    const hours = Array.from({ length: 24 }, () => 0);
    const weekdayTotals = Array.from({ length: 7 }, () => 0);
    const firstMonth = localDateKey(now, timeZone).slice(0, 7);
    const monthKeys = Array.from({ length: INSIGHT_MONTHS }, (_, back) => {
      const [year, month] = firstMonth.split('-').map(Number);
      const date = new Date(
        Date.UTC(year, month - 1 - (INSIGHT_MONTHS - 1 - back), 1),
      );
      return date.toISOString().slice(0, 7);
    });
    for (const key of monthKeys) months.set(key, new Map());
    let longest = 0;
    let total = 0;

    for (const session of sessions) {
      const at = session.startedAt.getTime();
      const date = localDateKey(at, timeZone);
      days.set(date, (days.get(date) ?? 0) + session.focusedMs);
      const month = months.get(date.slice(0, 7));
      if (month)
        StatsService.add(
          month,
          {
            key: session.categoryKey,
            name: session.categoryName,
            symbol: session.categorySymbol,
            color: session.categoryColor,
          },
          session.focusedMs,
        );
      const labels = Object.fromEntries(
        parts.formatToParts(at).map((part) => [part.type, part.value]),
      );
      hours[Number(labels.hour)] += session.focusedMs;
      weekdayTotals[weekdays.indexOf(labels.weekday)] += session.focusedMs;
      longest = Math.max(longest, session.focusedMs);
      total += session.focusedMs;
    }

    const peak = (values: number[]) => {
      const max = Math.max(...values);
      return max > 0 ? values.indexOf(max) : null;
    };
    const bestWeekday = peak(weekdayTotals);
    return {
      days: [...days].map(([date, ms]) => ({ date, ms })),
      months: monthKeys.map((month) => {
        const categories = StatsService.sorted(months.get(month));
        return {
          month,
          totalMs: categories.reduce((sum, c) => sum + c.ms, 0),
          categories,
        };
      }),
      bestHour: peak(hours),
      bestWeekday: bestWeekday === null ? null : bestWeekday + 1,
      averageSessionMs: sessions.length
        ? Math.round(total / sessions.length)
        : 0,
      longestSessionMs: longest,
    };
  }

  /** All recorded sessions, newest first, for a CSV file on the device. */
  async export(userId: string): Promise<ExportedSession[]> {
    const rows = await this.prisma.focusSession.findMany({
      where: { userId },
      orderBy: { startedAt: 'desc' },
      take: EXPORT_LIMIT,
      select: {
        startedAt: true,
        endedAt: true,
        focusedMs: true,
        categoryName: true,
        roomName: true,
        mode: true,
        note: true,
      },
    });
    return rows.map((row) => ({
      startedAt: row.startedAt.getTime(),
      endedAt: row.endedAt.getTime(),
      focusedMs: row.focusedMs,
      category: row.categoryName,
      roomName: row.roomName,
      mode: row.mode,
      note: row.note,
    }));
  }

  async history(
    userId: string,
    before: number | undefined,
    limit: number,
  ): Promise<{ entries: HistoryEntry[]; hasMore: boolean }> {
    const rows = await this.prisma.focusSession.findMany({
      where: {
        userId,
        ...(before ? { startedAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { startedAt: 'desc' },
      take: limit + 1,
    });
    const entries = rows.slice(0, limit).map((row) => ({
      id: row.id,
      roomId: row.roomId,
      roomName: row.roomName,
      mode: row.mode,
      category: {
        key: row.categoryKey,
        name: row.categoryName,
        symbol: row.categorySymbol,
        color: row.categoryColor,
      },
      note: row.note,
      startedAt: row.startedAt.getTime(),
      endedAt: row.endedAt.getTime(),
      focusedMs: row.focusedMs,
    }));
    return { entries, hasMore: rows.length > limit };
  }

  private static add(
    totals: Map<string, CategoryTotal>,
    category: CategoryInfo,
    ms: number,
  ): void {
    const current = totals.get(category.key);
    totals.set(category.key, { ...category, ms: (current?.ms ?? 0) + ms });
  }

  private static sorted(
    totals: Map<string, CategoryTotal> | undefined,
  ): CategoryTotal[] {
    return [...(totals?.values() ?? [])].sort((a, b) => b.ms - a.ms);
  }

  private static streak(
    activeDays: Set<string>,
    todayStart: number,
    timeZone: string,
  ): number {
    const dayKey = (offset: number) =>
      localDateKey(todayStart - offset * DAY_MS + DAY_MS / 2, timeZone);
    let offset = activeDays.has(dayKey(0)) ? 0 : 1;
    let streak = 0;
    while (activeDays.has(dayKey(offset))) {
      streak += 1;
      offset += 1;
    }
    return streak;
  }
}
