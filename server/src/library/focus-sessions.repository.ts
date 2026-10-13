import { Injectable } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { DeskRecord, VacateReason } from './library.types.js';

/** Sessions shorter than this are treated as accidental sits and not recorded. */
const MINIMUM_RECORDED_FOCUS_MS = 60_000;

export function focusedMsAt(desk: DeskRecord, now: number): number {
  return (
    desk.focusAccumulatedMs +
    (desk.status === 'FOCUS' ? Math.max(0, now - desk.statusSince) : 0)
  );
}

@Injectable()
export class FocusSessionsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async record(
    roomId: string,
    desk: DeskRecord,
    endedAt: number,
    endReason: VacateReason,
  ): Promise<void> {
    const focusedMs = focusedMsAt(desk, endedAt);
    if (focusedMs < MINIMUM_RECORDED_FOCUS_MS) return;
    await this.prisma.focusSession.create({
      data: {
        userId: desk.userId,
        roomId,
        deskId: desk.deskId,
        taskLabel: desk.taskLabel,
        startedAt: new Date(desk.startedAt),
        endedAt: new Date(endedAt),
        focusedMs,
        endReason,
      },
    });
  }

  countSince(userId: string, since: Date): Promise<number> {
    return this.prisma.focusSession.count({
      where: { userId, startedAt: { gte: since } },
    });
  }
}
