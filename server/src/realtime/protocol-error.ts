export type ProtocolErrorCode =
  | 'UNAUTHORIZED'
  | 'INVALID_CODE'
  | 'RATE_LIMITED'
  | 'UNAVAILABLE'
  | 'INVALID_PAYLOAD'
  | 'ROOM_NOT_FOUND'
  | 'NOT_IN_ROOM'
  | 'DESK_NOT_FOUND'
  | 'DESK_TAKEN'
  | 'NOT_SEATED'
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
