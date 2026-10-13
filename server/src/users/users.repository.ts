import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../infra/prisma.service.js';
import { DEFAULT_AVATAR_SPRITE_ID } from './avatar-catalog.js';
import { UserProfile } from './user.js';

const profileSelect = {
  id: true,
  displayName: true,
  avatarSpriteId: true,
} as const;

export type IdentityProvider = 'apple' | 'google' | 'email';

export interface SignInIdentity {
  provider: IdentityProvider;
  /** Provider's stable user id; for e-mail sign-in, the address itself. */
  subject: string;
  /** A verified address, used to link providers to one account. */
  email?: string;
  /** Only used when the account is created. */
  displayName?: string;
}

type ProviderKey =
  { appleSubject: string } | { googleSubject: string } | { email: string };

function providerKey({ provider, subject }: SignInIdentity): ProviderKey {
  switch (provider) {
    case 'apple':
      return { appleSubject: subject };
    case 'google':
      return { googleSubject: subject };
    case 'email':
      return { email: subject };
  }
}

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Finds the account for this sign-in, linking it to an existing account with the same verified
   * e-mail address, or creates a new one.
   */
  async signIn(identity: SignInIdentity): Promise<UserProfile> {
    try {
      return await this.findOrLink(identity);
    } catch (error) {
      // Two first sign-ins raced to create the same account; the loser simply reads the winner's row.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        return this.findOrLink(identity);
      }
      throw error;
    }
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

  private async findOrLink(identity: SignInIdentity): Promise<UserProfile> {
    const key = providerKey(identity);
    const existing = await this.prisma.user.findUnique({
      where: key,
      select: profileSelect,
    });
    if (existing) return existing;

    if (identity.email) {
      const sameEmail = await this.prisma.user.findUnique({
        where: { email: identity.email },
        select: { id: true },
      });
      if (sameEmail) {
        return this.prisma.user.update({
          where: { id: sameEmail.id },
          data: key,
          select: profileSelect,
        });
      }
    }

    return this.prisma.user.create({
      data: {
        ...key,
        email: identity.email,
        displayName:
          identity.displayName ?? UsersRepository.fallbackName(identity),
        avatarSpriteId: DEFAULT_AVATAR_SPRITE_ID,
      },
      select: profileSelect,
    });
  }

  private static fallbackName({ email, subject }: SignInIdentity): string {
    const localPart =
      email?.split('@')[0]?.replace(/[^\p{L}\p{N}]/gu, '') ?? '';
    if (localPart.length >= 2) {
      return (
        localPart.charAt(0).toLocaleUpperCase('tr') + localPart.slice(1, 24)
      );
    }
    let hash = 0;
    for (const character of subject)
      hash = (hash * 31 + character.charCodeAt(0)) >>> 0;
    return `Okur ${(hash % 9000) + 1000}`;
  }
}
