import { randomInt } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { Glyph } from '../common/glyph.js';
import { PrismaService } from '../infra/prisma.service.js';
import { PublicUser } from '../users/user.js';

export type RoomVisibility = 'PUBLIC' | 'PRIVATE';

export interface RoomRecord {
  id: string;
  code: string;
  name: string;
  symbol: string;
  color: string;
  visibility: RoomVisibility;
  ownerId: string;
  createdAt: Date;
}

const roomSelect = {
  id: true,
  code: true,
  name: true,
  symbol: true,
  color: true,
  visibility: true,
  ownerId: true,
  createdAt: true,
} as const;
const publicUserSelect = {
  id: true,
  username: true,
  displayName: true,
  avatarSpriteId: true,
} as const;
const MAX_LISTED_MEMBERS = 200;
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** Durable data of user-created rooms. Who is inside right now lives in Redis (`RoomDirectory`). */
@Injectable()
export class RoomsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    ownerId: string,
    name: string,
    glyph: Glyph,
    visibility: RoomVisibility,
  ): Promise<RoomRecord> {
    for (;;) {
      const code = Array.from(
        { length: 6 },
        () => CODE_ALPHABET[randomInt(CODE_ALPHABET.length)],
      ).join('');
      try {
        return await this.prisma.room.create({
          data: {
            code,
            name,
            ...glyph,
            visibility,
            ownerId,
            memberships: { create: { userId: ownerId } },
          },
          select: roomSelect,
        });
      } catch (error) {
        const isCodeClash =
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002';
        if (!isCodeClash) throw error;
      }
    }
  }

  update(
    id: string,
    changes: Partial<
      Pick<RoomRecord, 'name' | 'symbol' | 'color' | 'visibility'>
    >,
  ): Promise<RoomRecord> {
    return this.prisma.room.update({
      where: { id },
      data: changes,
      select: roomSelect,
    });
  }

  findById(id: string): Promise<RoomRecord | null> {
    return this.prisma.room.findUnique({ where: { id }, select: roomSelect });
  }

  findByCode(code: string): Promise<RoomRecord | null> {
    return this.prisma.room.findUnique({ where: { code }, select: roomSelect });
  }

  countOwned(ownerId: string): Promise<number> {
    return this.prisma.room.count({ where: { ownerId } });
  }

  ownedRoomIds(ownerId: string): Promise<string[]> {
    return this.prisma.room
      .findMany({ where: { ownerId }, select: { id: true } })
      .then((rooms) => rooms.map((room) => room.id));
  }

  async isMember(userId: string, roomId: string): Promise<boolean> {
    return (
      (await this.prisma.roomMembership.count({ where: { userId, roomId } })) >
      0
    );
  }

  async touchMembership(userId: string, roomId: string): Promise<void> {
    await this.prisma.roomMembership.upsert({
      where: { userId_roomId: { userId, roomId } },
      update: { lastVisitedAt: new Date() },
      create: { userId, roomId },
    });
  }

  /** Rooms the reader created or visited, most recent first. */
  async listMine(userId: string, take = 20): Promise<RoomRecord[]> {
    const memberships = await this.prisma.roomMembership.findMany({
      where: { userId },
      orderBy: { lastVisitedAt: 'desc' },
      take,
      select: { room: { select: roomSelect } },
    });
    return memberships.map((membership) => membership.room);
  }

  listPublic(take = 200): Promise<RoomRecord[]> {
    return this.prisma.room.findMany({
      where: { visibility: 'PUBLIC' },
      orderBy: { createdAt: 'desc' },
      take,
      select: roomSelect,
    });
  }

  /** Members per room, for community size in Keşfet. */
  async memberCounts(roomIds: string[]): Promise<Map<string, number>> {
    const groups = await this.prisma.roomMembership.groupBy({
      by: ['roomId'],
      where: { roomId: { in: roomIds } },
      _count: { _all: true },
    });
    return new Map(groups.map((group) => [group.roomId, group._count._all]));
  }

  /** Member ids, most recently active first. */
  async memberIds(roomId: string): Promise<string[]> {
    const memberships = await this.prisma.roomMembership.findMany({
      where: { roomId },
      orderBy: { lastVisitedAt: 'desc' },
      take: MAX_LISTED_MEMBERS,
      select: { userId: true },
    });
    return memberships.map((membership) => membership.userId);
  }

  /** Removes the reader from the room's members and keeps them out until unbanned. */
  async ban(userId: string, roomId: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.roomMembership.deleteMany({ where: { userId, roomId } }),
      this.prisma.roomBan.upsert({
        where: { roomId_userId: { roomId, userId } },
        update: {},
        create: { roomId, userId },
      }),
    ]);
  }

  async unban(userId: string, roomId: string): Promise<void> {
    await this.prisma.roomBan.deleteMany({ where: { userId, roomId } });
  }

  async isBanned(userId: string, roomId: string): Promise<boolean> {
    return (await this.prisma.roomBan.count({ where: { userId, roomId } })) > 0;
  }

  /** Readers banned from the room, most recent first. */
  async banned(roomId: string): Promise<PublicUser[]> {
    const bans = await this.prisma.roomBan.findMany({
      where: { roomId },
      orderBy: { createdAt: 'desc' },
      select: { user: { select: publicUserSelect } },
    });
    return bans.map((ban) => ban.user);
  }

  /** Rooms the reader may not enter, so Keşfet can leave them out. */
  async bannedRoomIds(userId: string): Promise<Set<string>> {
    const bans = await this.prisma.roomBan.findMany({
      where: { userId },
      select: { roomId: true },
    });
    return new Set(bans.map((ban) => ban.roomId));
  }

  async removeMembership(userId: string, roomId: string): Promise<void> {
    await this.prisma.roomMembership.deleteMany({ where: { userId, roomId } });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.room.delete({ where: { id } });
  }
}
