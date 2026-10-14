import { randomInt } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../infra/prisma.service.js';

export type RoomVisibility = 'PUBLIC' | 'PRIVATE';

export interface RoomRecord {
  id: string;
  code: string;
  name: string;
  emoji: string;
  visibility: RoomVisibility;
  ownerId: string;
}

const roomSelect = {
  id: true,
  code: true,
  name: true,
  emoji: true,
  visibility: true,
  ownerId: true,
} as const;
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** Durable data of user-created rooms. Who is inside right now lives in Redis (`RoomDirectory`). */
@Injectable()
export class RoomsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    ownerId: string,
    name: string,
    emoji: string,
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
            emoji,
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

  listPublic(take = 50): Promise<RoomRecord[]> {
    return this.prisma.room.findMany({
      where: { visibility: 'PUBLIC' },
      orderBy: { createdAt: 'desc' },
      take,
      select: roomSelect,
    });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.room.delete({ where: { id } });
  }
}
