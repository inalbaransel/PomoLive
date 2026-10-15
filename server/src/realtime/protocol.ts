import { z } from 'zod';
import { GLYPH_COLORS, GLYPH_SYMBOLS } from '../common/glyph.js';
import { AVATAR_SPRITE_IDS } from '../users/avatar-catalog.js';
import { ProtocolError } from './protocol-error.js';

/**
 * Wire contract. Every frame is `{ "event": string, "data": object }`.
 * Client commands carry a `ref` inside `data`; the server answers each with a `reply` event
 * echoing that `ref`. Room changes are pushed as broadcast events without a `ref`.
 */
export const ClientEvent = {
  auth: 'auth',
  listRooms: 'room:list',
  discoverRooms: 'room:discover',
  joinRoom: 'room:join',
  createRoom: 'room:create',
  deleteRoom: 'room:delete',
  forgetRoom: 'room:forget',
  leaveRoom: 'room:leave',
  sit: 'desk:sit',
  stand: 'desk:stand',
  changeTimer: 'desk:timer',
  mySeat: 'desk:mine',
  heartbeat: 'presence:heartbeat',
  updateProfile: 'profile:update',
  listCategories: 'category:list',
  createCategory: 'category:create',
  deleteCategory: 'category:delete',
  statsSummary: 'stats:summary',
  history: 'history:list',
  deleteAccount: 'account:delete',
} as const;

export const ServerEvent = {
  reply: 'reply',
  deskOccupied: 'desk:occupied',
  deskUpdated: 'desk:updated',
  deskVacated: 'desk:vacated',
  presence: 'room:presence',
  roomClosed: 'room:closed',
} as const;

const displayName = z.string().trim().min(2).max(24);
const timeZone = z
  .string()
  .refine(
    (zone) =>
      Intl.supportedValuesOf('timeZone').includes(zone) || zone === 'UTC',
  )
  .default('UTC');
const email = z
  .string()
  .trim()
  .toLowerCase()
  .pipe(z.email())
  .pipe(z.string().max(254));
const password = z.string().min(8).max(128);
const uuid = z.uuid();
/** A short label: no control or invisible format characters. */
const label = (min: number, max: number) =>
  z
    .string()
    .trim()
    .min(min)
    .max(max)
    .regex(/^[^\p{Cc}\p{Cf}]+$/u);
const glyph = {
  symbol: z.enum(GLYPH_SYMBOLS),
  color: z.enum(GLYPH_COLORS),
};
const roomCode = z
  .string()
  .trim()
  .toUpperCase()
  .regex(/^[A-Z0-9]{6}$/);

export const refSchema = z.object({ ref: z.string().min(1).max(64) });

export const authCommandSchema = z.discriminatedUnion('method', [
  z.object({
    method: z.literal('register'),
    email,
    password,
    displayName: displayName.optional(),
    timeZone,
  }),
  z.object({ method: z.literal('password'), email, password, timeZone }),
  z.object({
    method: z.literal('session'),
    sessionToken: z.string().min(1),
    timeZone,
  }),
]);

export const joinRoomSchema = z
  .object({
    roomId: z.union([z.string().regex(/^pixel-hall-\d+$/), uuid]).optional(),
    code: roomCode.optional(),
  })
  .refine((target) => !(target.roomId && target.code), {
    message: 'Pass either roomId or code',
  });

export const createRoomSchema = z.object({
  name: label(2, 32),
  ...glyph,
  visibility: z.enum(['PUBLIC', 'PRIVATE']),
});

export const deleteRoomSchema = z.object({ roomId: uuid });

export const sitSchema = z.object({
  deskId: z.string().regex(/^desk_\d{1,3}$/),
  timer: z.discriminatedUnion('mode', [
    z.object({
      mode: z.literal('POMODORO'),
      focusMinutes: z.number().int().min(5).max(180),
      breakMinutes: z.number().int().min(1).max(60),
    }),
    z.object({ mode: z.literal('STOPWATCH') }),
  ]),
  categoryKey: z.string().min(1).max(64),
  note: label(1, 48).optional(),
});

export const changeTimerSchema = z.object({
  action: z.enum(['BREAK', 'RESUME']),
});

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

export const createCategorySchema = z.object({ name: label(2, 24), ...glyph });

export const deleteCategorySchema = z.object({ id: uuid });

export const historySchema = z.object({
  before: z.number().int().positive().optional(),
  limit: z.number().int().min(1).max(50).default(30),
});

export const deleteAccountSchema = z.object({ password });

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
