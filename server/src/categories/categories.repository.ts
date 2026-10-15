import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { Glyph } from '../common/glyph.js';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import {
  BUILT_IN_CATEGORIES,
  CategoryInfo,
  CUSTOM_CATEGORY_PREFIX,
} from './built-in-categories.js';

const MAX_CUSTOM_CATEGORIES = 20;

export interface CustomCategory extends CategoryInfo {
  id: string;
}

@Injectable()
export class CategoriesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async listCustom(userId: string): Promise<CustomCategory[]> {
    const categories = await this.prisma.category.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      select: { id: true, name: true, symbol: true, color: true },
    });
    return categories.map((category) => ({
      ...category,
      key: `${CUSTOM_CATEGORY_PREFIX}${category.id}`,
    }));
  }

  async create(
    userId: string,
    name: string,
    glyph: Glyph,
  ): Promise<CustomCategory> {
    if (
      (await this.prisma.category.count({ where: { userId } })) >=
      MAX_CUSTOM_CATEGORIES
    ) {
      ProtocolError.throw(
        'LIMIT_REACHED',
        `At most ${MAX_CUSTOM_CATEGORIES} categories`,
      );
    }
    try {
      const category = await this.prisma.category.create({
        data: { userId, name, ...glyph },
        select: { id: true, name: true, symbol: true, color: true },
      });
      return { ...category, key: `${CUSTOM_CATEGORY_PREFIX}${category.id}` };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        ProtocolError.throw(
          'NAME_TAKEN',
          'A category with this name already exists',
        );
      }
      throw error;
    }
  }

  async delete(userId: string, id: string): Promise<void> {
    await this.prisma.category.deleteMany({ where: { id, userId } });
  }

  /** Resolves a category key the reader may use: a built-in one or one of their own. */
  async resolve(userId: string, key: string): Promise<CategoryInfo> {
    const builtIn = BUILT_IN_CATEGORIES.find(
      (category) => category.key === key,
    );
    if (builtIn) return builtIn;
    if (key.startsWith(CUSTOM_CATEGORY_PREFIX)) {
      const id = key.slice(CUSTOM_CATEGORY_PREFIX.length);
      const custom = await this.prisma.category.findFirst({
        where: { id, userId },
        select: { name: true, symbol: true, color: true },
      });
      if (custom) return { key, ...custom };
    }
    return ProtocolError.throw('CATEGORY_NOT_FOUND', 'Unknown category');
  }
}
