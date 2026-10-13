import { z } from 'zod';
import { AVATAR_SPRITE_IDS } from '../users/avatar-catalog.js';
import { ProtocolError } from './protocol-error.js';

/**
 * Wire contract. Every frame is `{ "event": string, "data": object }`.
 * Client commands carry a `ref` inside `data`; the server answers each with a `reply` event
 * echoing that `ref`. Room changes are pushed as broadcast events without a `ref`.
 */
export const ClientEvent = {
  auth: 'auth',
  requestEmailCode: 'auth:email-code',
  joinRoom: 'room:join',
  createRoom: 'room:create',
  leaveRoom: 'room:leave',
  sit: 'desk:sit',
  stand: 'desk:stand',
  setStatus: 'desk:status',
  heartbeat: 'presence:heartbeat',
  updateProfile: 'profile:update',
} as const;

export const ServerEvent = {
  reply: 'reply',
  deskOccupied: 'desk:occupied',
  deskUpdated: 'desk:updated',
  deskVacated: 'desk:vacated',
  presence: 'room:presence',
} as const;

const displayName = z.string().trim().min(2).max(24);
const timeZone = z
  .string()
  .refine(
    (zone) =>
      Intl.supportedValuesOf('timeZone').includes(zone) || zone === 'UTC',
  )
  .default('UTC');

export const refSchema = z.object({ ref: z.string().min(1).max(64) });

const email = z
  .string()
  .trim()
  .toLowerCase()
  .pipe(z.email())
  .pipe(z.string().max(254));
const oidcCredential = {
  identityToken: z.string().min(1),
  rawNonce: z.string().min(16).max(128),
  displayName: displayName.optional(),
  timeZone,
};

export const authCommandSchema = z.discriminatedUnion('method', [
  z.object({ method: z.literal('apple'), ...oidcCredential }),
  z.object({ method: z.literal('google'), ...oidcCredential }),
  z.object({
    method: z.literal('email'),
    email,
    code: z.string().regex(/^\d{6}$/),
    displayName: displayName.optional(),
    timeZone,
  }),
  z.object({
    method: z.literal('session'),
    sessionToken: z.string().min(1),
    timeZone,
  }),
]);

export const requestEmailCodeSchema = z.object({ email });

export const joinRoomSchema = z.object({
  code: z
    .string()
    .trim()
    .toUpperCase()
    .regex(/^[A-Z0-9]{6}$/)
    .optional(),
});

export const sitSchema = z.object({
  deskId: z.string().regex(/^desk_\d{1,3}$/),
  taskLabel: z.string().trim().min(1).max(48),
});

export const setStatusSchema = z.object({ status: z.enum(['FOCUS', 'BREAK']) });

export const heartbeatSchema = z.object({
  background: z.boolean().default(false),
});

export const updateProfileSchema = z
  .object({
    displayName: displayName.optional(),
    avatarSpriteId: z.enum(AVATAR_SPRITE_IDS).optional(),
  })
  .refine(
    (changes) =>
      changes.displayName !== undefined || changes.avatarSpriteId !== undefined,
  );

export type AuthCommand = z.infer<typeof authCommandSchema>;

export function parsePayload<T extends z.ZodType>(
  schema: T,
  data: unknown,
): z.infer<T> {
  const result = schema.safeParse(data ?? {});
  if (!result.success)
    ProtocolError.throw('INVALID_PAYLOAD', z.prettifyError(result.error));
  return result.data;
}
