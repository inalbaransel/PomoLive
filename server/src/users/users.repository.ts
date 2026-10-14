import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { DEFAULT_AVATAR_SPRITE_ID } from './avatar-catalog.js';
import { UserProfile } from './user.js';

const profileSelect = {
  id: true,
  displayName: true,
  avatarSpriteId: true,
} as const;

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    email: string,
    passwordHash: string,
    displayName: string | undefined,
  ): Promise<UserProfile> {
    try {
      return await this.prisma.user.create({
        data: {
          email,
          passwordHash,
          displayName: displayName ?? UsersRepository.nameFromEmail(email),
          avatarSpriteId: DEFAULT_AVATAR_SPRITE_ID,
        },
        select: profileSelect,
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        ProtocolError.throw(
          'EMAIL_TAKEN',
          'An account with this e-mail already exists',
        );
      }
      throw error;
    }
  }

  findCredentials(
    email: string,
  ): Promise<(UserProfile & { passwordHash: string }) | null> {
    return this.prisma.user.findUnique({
      where: { email },
      select: { ...profileSelect, passwordHash: true },
    });
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

  update(
    id: string,
    changes: Partial<Omit<UserProfile, 'id'>>,
  ): Promise<UserProfile> {
    return this.prisma.user.update({
      where: { id },
      data: changes,
      select: profileSelect,
    });
  }

  /** `baransel@…` → "Baransel". */
  private static nameFromEmail(email: string): string {
    const localPart = email.split('@')[0].replace(/[^\p{L}\p{N}]/gu, '');
    if (localPart.length < 2) return 'Okur';
    return localPart.charAt(0).toLocaleUpperCase('tr') + localPart.slice(1, 24);
  }
}
