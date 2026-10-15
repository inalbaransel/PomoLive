import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { DEFAULT_AVATAR_SPRITE_ID } from './avatar-catalog.js';
import { ProfileChanges, PublicUser, UserProfile } from './user.js';

const publicSelect = {
  id: true,
  username: true,
  displayName: true,
  avatarSpriteId: true,
} as const;

const profileSelect = {
  ...publicSelect,
  bio: true,
  statsVisible: true,
} as const;

export interface UserCard extends PublicUser {
  bio: string | null;
  statsVisible: boolean;
  createdAt: Date;
}

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    email: string,
    passwordHash: string,
    username: string,
    displayName: string | undefined,
  ): Promise<UserProfile> {
    try {
      return await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          username,
          displayName: displayName ?? username,
          avatarSpriteId: DEFAULT_AVATAR_SPRITE_ID,
        },
        select: profileSelect,
      });
    } catch (error) {
      UsersRepository.rethrowUniqueClash(error);
    }
  }

  /** Signs in with either the e-mail address or the username. */
  findCredentials(
    login: string,
  ): Promise<(UserProfile & { passwordHash: string }) | null> {
    return this.prisma.user.findUnique({
      where: login.includes('@') ? { email: login } : { username: login },
      select: { ...profileSelect, passwordHash: true },
    });
  }

  async isUsernameTaken(username: string): Promise<boolean> {
    return (await this.prisma.user.count({ where: { username } })) > 0;
  }

  async passwordHash(id: string): Promise<string | null> {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: { passwordHash: true },
    });
    return user?.passwordHash ?? null;
  }

  /** Removes the account with its sessions, categories, memberships and owned rooms. */
  async delete(id: string): Promise<void> {
    await this.prisma.user.delete({ where: { id } });
  }

  findById(id: string): Promise<UserProfile | null> {
    return this.prisma.user.findUnique({
      where: { id },
      select: profileSelect,
    });
  }

  /** A reader as shown on their profile page. */
  findCard(id: string): Promise<UserCard | null> {
    return this.prisma.user.findUnique({
      where: { id },
      select: { ...profileSelect, createdAt: true },
    });
  }

  /** Public data and the stats setting of several readers at once. */
  async findMany(
    ids: string[],
  ): Promise<Map<string, PublicUser & { statsVisible: boolean }>> {
    const users = await this.prisma.user.findMany({
      where: { id: { in: ids } },
      select: { ...publicSelect, statsVisible: true },
    });
    return new Map(users.map((user) => [user.id, user]));
  }

  async update(id: string, changes: ProfileChanges): Promise<UserProfile> {
    try {
      return await this.prisma.user.update({
        where: { id },
        data: changes,
        select: profileSelect,
      });
    } catch (error) {
      UsersRepository.rethrowUniqueClash(error);
    }
  }

  private static rethrowUniqueClash(error: unknown): never {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      const fields = JSON.stringify(error.meta ?? {});
      if (fields.includes('username'))
        ProtocolError.throw('USERNAME_TAKEN', 'This username is taken');
      ProtocolError.throw(
        'EMAIL_TAKEN',
        'An account with this e-mail already exists',
      );
    }
    throw error;
  }
}
