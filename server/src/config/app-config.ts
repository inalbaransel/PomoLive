import { z } from 'zod';

/** Compose passes unset variables as empty strings; treat those as absent. */
const optional = <T extends z.ZodType>(schema: T) =>
  z.preprocess(
    (value) => (value === '' ? undefined : value),
    schema.optional(),
  );

const environmentSchema = z.object({
  NODE_ENV: z
    .enum(['development', 'test', 'production'])
    .default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.url(),
  REDIS_URL: z.url(),
  SESSION_SECRET: z.string().min(32),
  /** Readers in a public hall before new arrivals are routed to a fresh one. */
  SHARD_THRESHOLD: z.coerce.number().int().min(1).default(25),
  FOREGROUND_LEASE_SECONDS: z.coerce.number().int().min(15).default(90),
  BACKGROUND_LEASE_SECONDS: z.coerce
    .number()
    .int()
    .min(60)
    .default(45 * 60),
  /** APNs token auth (a .p8 key from the Apple Developer account). Push stays off without all three. */
  APNS_KEY_ID: optional(z.string().length(10)),
  APNS_TEAM_ID: optional(z.string().length(10)),
  /** The .p8 file's contents; `\n` escapes are accepted for one-line environment UIs. */
  APNS_PRIVATE_KEY: optional(z.string()),
  APNS_BUNDLE_ID: z.string().default('com.baransel.pomolive'),
  /**
   * SHA-256 fingerprint of Apple Root CA - G3, which signs App Store transactions. Pinned here so a
   * forged certificate chain cannot unlock Plus; override only if Apple rotates its root.
   */
  APPLE_ROOT_CA_SHA256: z
    .string()
    .default(
      '63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79',
    ),
  /** Accepts transactions signed by Xcode's local StoreKit testing. Never enable in production. */
  ALLOW_XCODE_TRANSACTIONS: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
  /** Shown on the support page; the page leaves contact details out without it. */
  SUPPORT_EMAIL: optional(z.email()),
});

export interface ApnsCredentials {
  keyId: string;
  teamId: string;
  privateKey: string;
  bundleId: string;
}

/** Validated, typed runtime configuration. Injected by class token. */
export class AppConfig {
  readonly nodeEnv: 'development' | 'test' | 'production';
  readonly port: number;
  readonly databaseUrl: string;
  readonly redisUrl: string;
  readonly sessionSecret: string;
  readonly shardThreshold: number;
  readonly foregroundLeaseMs: number;
  readonly backgroundLeaseMs: number;
  readonly bundleId: string;
  readonly appleRootFingerprint: string;
  readonly allowsXcodeTransactions: boolean;
  readonly apns: ApnsCredentials | null;
  readonly supportEmail: string | null;

  static fromEnvironment(source: NodeJS.ProcessEnv): AppConfig {
    const result = environmentSchema.safeParse(source);
    if (!result.success) {
      throw new Error(`Invalid environment:\n${z.prettifyError(result.error)}`);
    }
    const env = result.data;
    return Object.assign(new AppConfig(), {
      nodeEnv: env.NODE_ENV,
      port: env.PORT,
      databaseUrl: env.DATABASE_URL,
      redisUrl: env.REDIS_URL,
      sessionSecret: env.SESSION_SECRET,
      shardThreshold: env.SHARD_THRESHOLD,
      foregroundLeaseMs: env.FOREGROUND_LEASE_SECONDS * 1000,
      backgroundLeaseMs: env.BACKGROUND_LEASE_SECONDS * 1000,
      bundleId: env.APNS_BUNDLE_ID,
      appleRootFingerprint: env.APPLE_ROOT_CA_SHA256.toUpperCase(),
      allowsXcodeTransactions: env.ALLOW_XCODE_TRANSACTIONS,
      apns:
        env.APNS_KEY_ID && env.APNS_TEAM_ID && env.APNS_PRIVATE_KEY
          ? {
              keyId: env.APNS_KEY_ID,
              teamId: env.APNS_TEAM_ID,
              privateKey: env.APNS_PRIVATE_KEY.replaceAll('\\n', '\n'),
              bundleId: env.APNS_BUNDLE_ID,
            }
          : null,
      supportEmail: env.SUPPORT_EMAIL ?? null,
    });
  }
}
