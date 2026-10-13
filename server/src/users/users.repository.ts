import { Injectable } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { DEFAULT_AVATAR_SPRITE_ID } from './avatar-catalog.js';
import { UserProfile } from './user.js';

const profileSelect = { id: true, displayName: true, avatarSpriteId: true } as const;

type Identity = { kind: 'apple' | 'dev'; subject: string };

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** Apple only shares the user's name on the very first sign-in, so it is used for creation only. */
  upsertByIdentity(identity: Identity, displayName: string | undefined): Promise<UserProfile> {
    const where = identity.kind === 'apple' ? { appleSubject: identity.subject } : { devSubject: identity.subject };
    return this.prisma.user.upsert({
      where,
      update: {},
      create: {
        ...where,
        displayName: displayName ?? UsersRepository.fallbackName(identity.subject),
        avatarSpriteId: DEFAULT_AVATAR_SPRITE_ID,
      },
      select: profileSelect,
    });
  }

  findById(id: string): Promise<UserProfile | null> {
    return this.prisma.user.findUnique({ where: { id }, select: profileSelect });
  }

  update(id: string, changes: Partial<Omit<UserProfile, 'id'>>): Promise<UserProfile> {
    return this.prisma.user.update({ where: { id }, data: changes, select: profileSelect });
  }

  private static fallbackName(subject: string): string {
    let hash = 0;
    for (const character of subject) hash = (hash * 31 + character.charCodeAt(0)) >>> 0;
    return `Okur ${(hash % 9000) + 1000}`;
  }
}
