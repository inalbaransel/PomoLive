import { z } from 'zod';

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
});

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
    });
  }
}
