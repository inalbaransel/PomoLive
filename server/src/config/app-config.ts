import { z } from 'zod';

const booleanFlag = z
  .enum(['true', 'false'])
  .default('false')
  .transform((value) => value === 'true');

const environmentSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.coerce.number().int().positive().default(3000),
    DATABASE_URL: z.url(),
    REDIS_URL: z.url(),
    SESSION_SECRET: z.string().min(32),
    APPLE_BUNDLE_ID: z.string().min(1),
    DEV_AUTH_ENABLED: booleanFlag,
    /** Readers in a public hall before new arrivals are routed to a fresh one. */
    SHARD_THRESHOLD: z.coerce.number().int().min(1).default(25),
    FOCUS_MINUTES: z.coerce.number().int().min(1).default(25),
    BREAK_MINUTES: z.coerce.number().int().min(1).default(5),
    FOREGROUND_LEASE_SECONDS: z.coerce.number().int().min(15).default(90),
    BACKGROUND_LEASE_SECONDS: z.coerce.number().int().min(60).default(45 * 60),
  })
  .refine((env) => !(env.NODE_ENV === 'production' && env.DEV_AUTH_ENABLED), {
    message: 'DEV_AUTH_ENABLED must be false in production',
    path: ['DEV_AUTH_ENABLED'],
  });

/** Validated, typed runtime configuration. Injected by class token. */
export class AppConfig {
  readonly nodeEnv: 'development' | 'test' | 'production';
  readonly port: number;
  readonly databaseUrl: string;
  readonly redisUrl: string;
  readonly sessionSecret: string;
  readonly appleBundleId: string;
  readonly devAuthEnabled: boolean;
  readonly shardThreshold: number;
  readonly focusMinutes: number;
  readonly breakMinutes: number;
  readonly foregroundLeaseMs: number;
  readonly backgroundLeaseMs: number;

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
      appleBundleId: env.APPLE_BUNDLE_ID,
      devAuthEnabled: env.DEV_AUTH_ENABLED,
      shardThreshold: env.SHARD_THRESHOLD,
      focusMinutes: env.FOCUS_MINUTES,
      breakMinutes: env.BREAK_MINUTES,
      foregroundLeaseMs: env.FOREGROUND_LEASE_SECONDS * 1000,
      backgroundLeaseMs: env.BACKGROUND_LEASE_SECONDS * 1000,
    });
  }
}
