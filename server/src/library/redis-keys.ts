export const RedisKeys = {
  roomState: (roomId: string) => `room:${roomId}:state`,
  roomDesks: (roomId: string) => `room:${roomId}:desks`,
  roomPresence: (roomId: string) => `room:${roomId}:presence`,
  roomEvents: (roomId: string) => `room:${roomId}:events`,
  roomEventsPattern: 'room:*:events',
  publicRooms: 'rooms:public',
  privateRooms: 'rooms:private',
  roomSequence: 'rooms:sequence',
  userSeat: (userId: string) => `user:${userId}:seat`,
  deskLeases: 'desks:leases',
  reaperLock: 'lock:lease-reaper',
} as const;

export function roomIdFromEventsChannel(channel: string): string {
  return channel.slice('room:'.length, -':events'.length);
}
