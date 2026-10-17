import { Injectable, Logger } from '@nestjs/common';
import { AppConfig } from '../config/app-config.js';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import {
  InvalidTransactionError,
  verifySignedTransaction,
} from './app-store-jws.js';
import { PLUS_PRODUCT_IDS } from './plus-catalog.js';

export interface PlusStatus {
  active: boolean;
  /** ms epoch of the current period's end, while active. */
  expiresAt: number | null;
  productId: string | null;
}

/**
 * Who has PomoLive Plus. The device sends each signed transaction StoreKit gives it (on purchase,
 * renewal and launch); the server verifies it with Apple's certificate chain and keeps the latest
 * expiry, so Plus follows the account to every device and cannot be faked by a modified app.
 */
@Injectable()
export class PlusService {
  private readonly logger = new Logger(PlusService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: AppConfig,
  ) {}

  async status(userId: string, now = Date.now()): Promise<PlusStatus> {
    const current = await this.prisma.plusSubscription.findFirst({
      where: { userId, revoked: false, expiresAt: { gt: new Date(now) } },
      orderBy: { expiresAt: 'desc' },
      select: { expiresAt: true, productId: true },
    });
    return {
      active: current !== null,
      expiresAt: current?.expiresAt.getTime() ?? null,
      productId: current?.productId ?? null,
    };
  }

  async isActive(userId: string): Promise<boolean> {
    return (await this.status(userId)).active;
  }

  async require(userId: string): Promise<void> {
    if (!(await this.isActive(userId)))
      ProtocolError.throw('PLUS_REQUIRED', 'This needs PomoLive Plus');
  }

  async sync(userId: string, jws: string): Promise<PlusStatus> {
    const now = Date.now();
    let transaction;
    try {
      transaction = verifySignedTransaction(jws, {
        bundleId: this.config.bundleId,
        rootFingerprint: this.config.appleRootFingerprint,
        allowsXcode: this.config.allowsXcodeTransactions,
        now,
      });
    } catch (error) {
      if (!(error instanceof InvalidTransactionError)) throw error;
      this.logger.warn(`Rejected transaction: ${error.message}`);
      return ProtocolError.throw(
        'INVALID_PAYLOAD',
        'Purchase could not be verified',
      );
    }
    if (
      !(PLUS_PRODUCT_IDS as readonly string[]).includes(
        transaction.productId,
      ) ||
      !transaction.expiresDate
    )
      ProtocolError.throw('INVALID_PAYLOAD', 'Not a Plus subscription');

    const data = {
      userId,
      productId: transaction.productId,
      expiresAt: new Date(transaction.expiresDate),
      environment: transaction.environment,
      revoked: transaction.revocationDate !== undefined,
    };
    // An older transaction (e.g. replayed from a stale cache) never shortens the known period.
    const existing = await this.prisma.plusSubscription.findUnique({
      where: { originalTransactionId: transaction.originalTransactionId },
      select: { expiresAt: true },
    });
    if (
      !existing ||
      data.revoked ||
      existing.expiresAt.getTime() <= transaction.expiresDate
    ) {
      await this.prisma.plusSubscription.upsert({
        where: { originalTransactionId: transaction.originalTransactionId },
        create: {
          originalTransactionId: transaction.originalTransactionId,
          ...data,
        },
        update: data,
      });
    } else {
      await this.prisma.plusSubscription.update({
        where: { originalTransactionId: transaction.originalTransactionId },
        data: { userId },
      });
    }
    return this.status(userId, now);
  }
}
