import { Injectable } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';

/** Open tasks a reader may keep at once; finished ones do not count. */
const MAX_OPEN_TASKS = 50;
/** Finished tasks stay visible this long, so a day's progress can be looked back on. */
const DONE_VISIBLE_MS = 24 * 60 * 60_000;

export interface FocusTaskView {
  id: string;
  title: string;
  createdAt: number;
  completedAt: number | null;
}

const taskSelect = {
  id: true,
  title: true,
  createdAt: true,
  completedAt: true,
} as const;

/** A reader's personal to-do list for their focus sessions. */
@Injectable()
export class TasksService {
  constructor(private readonly prisma: PrismaService) {}

  /** Open tasks oldest first, then those finished in the last day. */
  async list(userId: string, now: number): Promise<FocusTaskView[]> {
    const rows = await this.prisma.focusTask.findMany({
      where: {
        userId,
        OR: [
          { completedAt: null },
          { completedAt: { gte: new Date(now - DONE_VISIBLE_MS) } },
        ],
      },
      orderBy: { createdAt: 'asc' },
      select: taskSelect,
    });
    return rows.map(TasksService.view);
  }

  async create(userId: string, title: string): Promise<FocusTaskView> {
    const open = await this.prisma.focusTask.count({
      where: { userId, completedAt: null },
    });
    if (open >= MAX_OPEN_TASKS)
      ProtocolError.throw(
        'LIMIT_REACHED',
        `At most ${MAX_OPEN_TASKS} open tasks`,
      );
    return TasksService.view(
      await this.prisma.focusTask.create({
        data: { userId, title },
        select: taskSelect,
      }),
    );
  }

  async setDone(
    userId: string,
    id: string,
    done: boolean,
  ): Promise<FocusTaskView> {
    await this.owned(userId, id);
    return TasksService.view(
      await this.prisma.focusTask.update({
        where: { id },
        data: { completedAt: done ? new Date() : null },
        select: taskSelect,
      }),
    );
  }

  async delete(userId: string, id: string): Promise<void> {
    await this.owned(userId, id);
    await this.prisma.focusTask.delete({ where: { id } });
  }

  private async owned(userId: string, id: string): Promise<void> {
    const task = await this.prisma.focusTask.findUnique({
      where: { id },
      select: { userId: true },
    });
    if (task?.userId !== userId)
      ProtocolError.throw('TASK_NOT_FOUND', 'No such task');
  }

  private static view(row: {
    id: string;
    title: string;
    createdAt: Date;
    completedAt: Date | null;
  }): FocusTaskView {
    return {
      id: row.id,
      title: row.title,
      createdAt: row.createdAt.getTime(),
      completedAt: row.completedAt?.getTime() ?? null,
    };
  }
}
