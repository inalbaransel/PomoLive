import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { PrismaService } from '../infra/prisma.service.js';
import {
  DAY_MS,
  localDateKey,
  startOfLocalDay,
  startOfLocalWeek,
} from '../library/local-day.js';

export interface CategoryTotal extends CategoryInfo {
  ms: number;
}

export interface DayTotal {
  date: string;
  totalMs: number;
  byCategory: CategoryTotal[];
}

export interface StatsSummary {
  todayMs: number;
  weekMs: number;
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
  constructor(private readonly prisma: PrismaService) {}

  async summary(
    userId: string,
    timeZone: string,
    now = Date.now(),
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
    };
  }

  /** Newest first; pass the last entry's `startedAt` as `before` to page further back. */
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
