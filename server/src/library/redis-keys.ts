export const RedisKeys = {
  roomState: (roomId: string) => `room:${roomId}:state`,
  roomDesks: (roomId: string) => `room:${roomId}:desks`,
  roomPresence: (roomId: string) => `room:${roomId}:presence`,
  roomEvents: (roomId: string) => `room:${roomId}:events`,
  roomEventsPattern: 'room:*:events',
  /** System halls, scored by sequence number. */
  halls: 'rooms:halls',
  hallSequence: 'rooms:hall-sequence',
  /** User rooms that currently have live state, scored by last activity. */
  liveRooms: 'rooms:live',
  userSeat: (userId: string) => `user:${userId}:seat`,
  deskLeases: 'desks:leases',
  reaperLock: 'lock:lease-reaper',
  /** Cached stats summaries of one reader, one hash field per time zone. */
  statsSummary: (userId: string) => `user:${userId}:stats`,
} as const;

export function roomIdFromEventsChannel(channel: string): string {
  return channel.slice('room:'.length, -':events'.length);
}
