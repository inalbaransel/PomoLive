import { Injectable } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { readTimer } from './desk-timer.js';
import { DeskRecord, VacateReason } from './library.types.js';

/** Sessions shorter than this are treated as accidental sits and not recorded. */
const MINIMUM_RECORDED_FOCUS_MS = 60_000;

@Injectable()
export class FocusSessionsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async record(
    room: { id: string; name: string },
    desk: DeskRecord,
    endedAt: number,
    reason: VacateReason,
  ): Promise<void> {
    const focusedMs = readTimer(desk.timer, endedAt).focusedMs;
    if (focusedMs < MINIMUM_RECORDED_FOCUS_MS) return;
    await this.prisma.focusSession.create({
      data: {
        userId: desk.userId,
        roomId: room.id,
        roomName: room.name.slice(0, 32),
        deskId: desk.deskId,
        mode: desk.timer.mode,
        categoryKey: desk.category.key,
        categoryName: desk.category.name,
        categorySymbol: desk.category.symbol,
        categoryColor: desk.category.color,
        note: desk.note,
        startedAt: new Date(desk.startedAt),
        endedAt: new Date(endedAt),
        focusedMs,
        endReason: reason === 'LEASE_EXPIRED' ? 'LEASE_EXPIRED' : 'STOOD_UP',
      },
    });
  }

  /** Recorded focus per reader in one room since `since`. */
  async focusByUser(
    roomId: string,
    userIds: string[],
    since: Date,
  ): Promise<Map<string, number>> {
    const groups = await this.prisma.focusSession.groupBy({
      by: ['userId'],
      where: { roomId, userId: { in: userIds }, startedAt: { gte: since } },
      _sum: { focusedMs: true },
    });
    return new Map(
      groups.map((group) => [group.userId, group._sum.focusedMs ?? 0]),
    );
  }

  countSince(userId: string, since: Date): Promise<number> {
    return this.prisma.focusSession.count({
      where: { userId, startedAt: { gte: since } },
    });
  }
}
