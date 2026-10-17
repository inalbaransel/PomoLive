import { Injectable, Logger } from '@nestjs/common';
import type { ReportReason } from '../generated/prisma/client.js';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { PublicUser } from '../users/user.js';

/** Distinct readers reporting the same chat line before it is taken down without waiting for review. */
const AUTO_REMOVE_REPORTS = 3;
const MAX_BLOCKS = 500;

const publicSelect = {
  id: true,
  username: true,
  displayName: true,
  avatarSpriteId: true,
} as const;

export interface ReportInput {
  userId: string;
  reason: ReportReason;
  note?: string;
  messageId?: string;
}

/**
 * Keeping readers safe from each other: blocking someone cuts every tie between the two
 * (follows, chat, search, profile), and reports are stored for review. A chat line enough people
 * report is removed at once.
 */
@Injectable()
export class ModerationService {
  private readonly logger = new Logger(ModerationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly bus: RoomEventBus,
  ) {}

  async block(blockerId: string, blockedId: string): Promise<void> {
    if (blockerId === blockedId)
      ProtocolError.throw('FORBIDDEN', 'You cannot block yourself');
    const exists = await this.prisma.user.count({ where: { id: blockedId } });
    if (!exists)
      ProtocolError.throw('USER_NOT_FOUND', 'No reader with this id');
    const count = await this.prisma.userBlock.count({ where: { blockerId } });
    if (count >= MAX_BLOCKS)
      ProtocolError.throw('LIMIT_REACHED', `At most ${MAX_BLOCKS} blocks`);
    await this.prisma.$transaction([
      this.prisma.userBlock.upsert({
        where: { blockerId_blockedId: { blockerId, blockedId } },
        update: {},
        create: { blockerId, blockedId },
      }),
      this.prisma.follow.deleteMany({
        where: {
          OR: [
            { followerId: blockerId, followeeId: blockedId },
            { followerId: blockedId, followeeId: blockerId },
          ],
        },
      }),
    ]);
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    await this.prisma.userBlock.deleteMany({ where: { blockerId, blockedId } });
  }

  /** The readers this one blocked, most recent first. */
  async blocked(blockerId: string): Promise<PublicUser[]> {
    const rows = await this.prisma.userBlock.findMany({
      where: { blockerId },
      orderBy: { createdAt: 'desc' },
      select: { blocked: { select: publicSelect } },
    });
    return rows.map((row) => row.blocked);
  }

  /** Everyone separated from this reader by a block, in either direction. */
  async separatedIds(userId: string): Promise<string[]> {
    const rows = await this.prisma.userBlock.findMany({
      where: { OR: [{ blockerId: userId }, { blockedId: userId }] },
      select: { blockerId: true, blockedId: true },
    });
    return rows.map((row) =>
      row.blockerId === userId ? row.blockedId : row.blockerId,
    );
  }

  async isSeparated(a: string, b: string): Promise<boolean> {
    const count = await this.prisma.userBlock.count({
      where: {
        OR: [
          { blockerId: a, blockedId: b },
          { blockerId: b, blockedId: a },
        ],
      },
    });
    return count > 0;
  }

  async hasBlocked(blockerId: string, blockedId: string): Promise<boolean> {
    return (
      (await this.prisma.userBlock.count({ where: { blockerId, blockedId } })) >
      0
    );
  }

  async report(reporterId: string, input: ReportInput): Promise<void> {
    if (reporterId === input.userId)
      ProtocolError.throw('FORBIDDEN', 'You cannot report yourself');
    const message = input.messageId
      ? ((await this.prisma.chatMessage.findUnique({
          where: { id: input.messageId },
          select: { id: true, userId: true, body: true, roomId: true },
        })) ?? ProtocolError.throw('MESSAGE_NOT_FOUND', 'Message is gone'))
      : null;
    if (message && message.userId !== input.userId)
      ProtocolError.throw('MESSAGE_NOT_FOUND', 'Message is gone');
    const exists = await this.prisma.user.count({
      where: { id: input.userId },
    });
    if (!exists)
      ProtocolError.throw('USER_NOT_FOUND', 'No reader with this id');

    // One open report per reporter, person and message; a repeat only refreshes the details.
    const previous = await this.prisma.report.findFirst({
      where: {
        reporterId,
        reportedId: input.userId,
        messageId: message?.id ?? null,
        status: 'OPEN',
      },
      select: { id: true },
    });
    const details = { reason: input.reason, note: input.note ?? null };
    if (previous) {
      await this.prisma.report.update({
        where: { id: previous.id },
        data: details,
      });
      return;
    }
    await this.prisma.report.create({
      data: {
        ...details,
        reporterId,
        reportedId: input.userId,
        messageId: message?.id,
        messageBody: message?.body,
        roomId: message?.roomId,
      },
    });
    this.logger.warn(
      `Report ${input.reason} against ${input.userId}${message ? ` for message ${message.id}` : ''}`,
    );
    if (message) await this.removeIfReportedEnough(message);
  }

  private async removeIfReportedEnough(message: {
    id: string;
    roomId: string;
  }): Promise<void> {
    const reporters = await this.prisma.report.findMany({
      where: { messageId: message.id },
      distinct: ['reporterId'],
      select: { reporterId: true },
    });
    if (reporters.length < AUTO_REMOVE_REPORTS) return;
    const { count } = await this.prisma.chatMessage.deleteMany({
      where: { id: message.id },
    });
    if (count === 0) return;
    this.logger.warn(`Removed message ${message.id} after repeated reports`);
    await this.bus.publish(message.roomId, ServerEvent.chatDeleted, {
      messageId: message.id,
    });
  }
}
