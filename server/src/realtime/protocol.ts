import { z } from 'zod';
import { GLYPH_COLORS, GLYPH_SYMBOLS } from '../common/glyph.js';
import { ROOM_THEMES } from '../library/layout/library-layout.js';
import { AVATAR_SPRITE_IDS } from '../users/avatar-catalog.js';
import { ProtocolError } from './protocol-error.js';

/**
 * Wire contract. Every frame is `{ "event": string, "data": object }`.
 * Client commands carry a `ref` inside `data`; the server answers each with a `reply` event
 * echoing that `ref`. Room changes are pushed as broadcast events without a `ref`.
 */
export const ClientEvent = {
  auth: 'auth',
  checkUsername: 'username:check',
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
  userProfile: 'user:profile',
  roomMembers: 'room:members',
  previewRoom: 'room:preview',
  updateRoom: 'room:update',
  removeMember: 'room:remove',
  unbanMember: 'room:unban',
  listCategories: 'category:list',
  createCategory: 'category:create',
  deleteCategory: 'category:delete',
  statsSummary: 'stats:summary',
  history: 'history:list',
  deleteAccount: 'account:delete',
  sendChat: 'chat:send',
  chatHistory: 'chat:history',
  deleteChat: 'chat:delete',
  chatTyping: 'chat:typing',
  listTasks: 'task:list',
  follow: 'user:follow',
  unfollow: 'user:unfollow',
  searchUsers: 'user:search',
  friends: 'friends:list',
  createTask: 'task:create',
  setTaskDone: 'task:done',
  deleteTask: 'task:delete',
} as const;

export const ServerEvent = {
  reply: 'reply',
  deskOccupied: 'desk:occupied',
  deskUpdated: 'desk:updated',
  deskVacated: 'desk:vacated',
  presence: 'room:presence',
  roomClosed: 'room:closed',
  roomUpdated: 'room:updated',
  memberRemoved: 'room:removed',
  chatMessage: 'chat:message',
  chatDeleted: 'chat:deleted',
  chatTyping: 'chat:typing',
  friendStarted: 'friend:started',
} as const;

const displayName = z.string().trim().min(2).max(24);
/** Lowercase letters, digits, `_` and `.`; no leading, trailing or doubled dot. */
const username = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^(?!\.)(?!.*\.\.)[a-z0-9._]{3,20}(?<!\.)$/);
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

/** A room's blurb: up to 200 characters, line breaks allowed; an empty string clears it. */
const roomDescription = z
  .string()
  .trim()
  .max(200)
  .regex(/^(?:[^\p{Cc}\p{Cf}]|\n)*$/u)
  .transform((text) => text || null);

export const refSchema = z.object({ ref: z.string().min(1).max(64) });

export const authCommandSchema = z.discriminatedUnion('method', [
  z.object({
    method: z.literal('register'),
    email,
    password,
    username,
    displayName: displayName.optional(),
    timeZone,
  }),
  z.object({
    method: z.literal('password'),
    login: z.string().trim().toLowerCase().min(3).max(254),
    password,
    timeZone,
  }),
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
  theme: z.enum(ROOM_THEMES).default('classic'),
  description: roomDescription.optional(),
});

export const deleteRoomSchema = z.object({ roomId: uuid });

export const previewRoomSchema = z.object({ roomId: uuid });

export const updateRoomSchema = z
  .object({
    roomId: uuid,
    name: label(2, 32).optional(),
    symbol: glyph.symbol.optional(),
    color: glyph.color.optional(),
    visibility: z.enum(['PUBLIC', 'PRIVATE']).optional(),
    theme: z.enum(ROOM_THEMES).optional(),
    description: roomDescription.optional(),
  })
  .refine((changes) => Object.keys(changes).length > 1, {
    message: 'Nothing to change',
  });

export const roomMembersSchema = z.object({
  roomId: z.union([z.string().regex(/^pixel-hall-\d+$/), uuid]),
});

export const roomMemberSchema = z.object({ roomId: uuid, userId: uuid });

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

export const checkUsernameSchema = z.object({ username });

export const updateProfileSchema = z
  .object({
    username: username.optional(),
    displayName: displayName.optional(),
    avatarSpriteId: z.enum(AVATAR_SPRITE_IDS).optional(),
    /** An empty string clears the bio. */
    bio: z
      .string()
      .trim()
      .max(80)
      .regex(/^[^\p{Cc}\p{Cf}]*$/u)
      .transform((bio) => bio || null)
      .optional(),
    statsVisible: z.boolean().optional(),
    /** 0 clears the goal. */
    dailyGoalMinutes: z
      .number()
      .int()
      .min(0)
      .max(16 * 60)
      .transform((minutes) => minutes || null)
      .optional(),
    weeklyGoalMinutes: z
      .number()
      .int()
      .min(0)
      .max(100 * 60)
      .transform((minutes) => minutes || null)
      .optional(),
  })
  .refine((changes) => Object.keys(changes).length > 0, {
    message: 'Nothing to change',
  });

export const userProfileSchema = z.object({ userId: uuid });

export const createCategorySchema = z.object({ name: label(2, 24), ...glyph });

export const deleteCategorySchema = z.object({ id: uuid });

export const historySchema = z.object({
  before: z.number().int().positive().optional(),
  limit: z.number().int().min(1).max(50).default(30),
});

export const sendChatSchema = z.object({
  /** Line breaks allowed; other control and invisible format characters are not. */
  body: z
    .string()
    .trim()
    .min(1)
    .max(500)
    .regex(/^(?:[^\p{Cc}\p{Cf}]|\n)+$/u),
  clientId: z.string().min(8).max(64),
});

export const chatHistorySchema = z.object({
  before: z.number().int().positive().optional(),
});

export const deleteChatSchema = z.object({ messageId: uuid });

export const createTaskSchema = z.object({ title: label(1, 120) });

export const setTaskDoneSchema = z.object({ id: uuid, done: z.boolean() });

export const deleteTaskSchema = z.object({ id: uuid });

export const searchUsersSchema = z.object({
  query: z.string().trim().min(2).max(24),
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
