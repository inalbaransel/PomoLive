export type ProtocolErrorCode =
  | 'UNAUTHORIZED'
  | 'INVALID_CREDENTIALS'
  | 'EMAIL_TAKEN'
  | 'USERNAME_TAKEN'
  | 'USER_NOT_FOUND'
  | 'RATE_LIMITED'
  | 'INVALID_PAYLOAD'
  | 'ROOM_NOT_FOUND'
  | 'NOT_IN_ROOM'
  | 'DESK_NOT_FOUND'
  | 'DESK_TAKEN'
  | 'NOT_SEATED'
  | 'FORBIDDEN'
  | 'BANNED'
  | 'LIMIT_REACHED'
  | 'NAME_TAKEN'
  | 'CATEGORY_NOT_FOUND'
  | 'INTERNAL';

/** A failure the client is expected to handle; serialised into a `reply` with `ok: false`. */
export class ProtocolError extends Error {
  constructor(
    readonly code: ProtocolErrorCode,
    message: string,
  ) {
    super(message);
  }

  static throw(code: ProtocolErrorCode, message: string): never {
    throw new ProtocolError(code, message);
  }
}
