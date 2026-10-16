import { Injectable } from '@nestjs/common';
import { PrismaService } from '../infra/prisma.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { ServerEvent } from '../realtime/protocol.js';
import { RoomEventBus } from '../realtime/room-event-bus.js';
import { RoomsRepository } from './rooms.repository.js';

const MAX_UPCOMING = 20;
const MAX_AHEAD_MS = 60 * 24 * 60 * 60_000;
/** An event stays listed until it has ended. */
const listedUntilEnd = (now: number) => ({
  gte: new Date(now - 8 * 60 * 60_000),
});

export interface RoomEventView {
  id: string;
  roomId: string;
  title: string;
  startsAt: number;
  durationMinutes: number;
  goingCount: number;
  isGoing: boolean;
}

/** Sessions an owner schedules in their room, and who plans to come. */
@Injectable()
export class RoomEventsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: RoomsRepository,
    private readonly bus: RoomEventBus,
  ) {}

  async list(
    userId: string,
    roomId: string,
    now: number,
  ): Promise<RoomEventView[]> {
    await this.ensureVisible(userId, roomId);
    const events = await this.prisma.roomEvent.findMany({
      where: { roomId, startsAt: listedUntilEnd(now) },
      orderBy: { startsAt: 'asc' },
      select: {
        id: true,
        roomId: true,
        title: true,
        startsAt: true,
        durationMinutes: true,
        _count: { select: { rsvps: true } },
        rsvps: { where: { userId }, select: { userId: true } },
      },
    });
    return events
      .filter(
        (event) =>
          event.startsAt.getTime() + event.durationMinutes * 60_000 > now,
      )
      .map((event) => ({
        id: event.id,
        roomId: event.roomId,
        title: event.title,
        startsAt: event.startsAt.getTime(),
        durationMinutes: event.durationMinutes,
        goingCount: event._count.rsvps,
        isGoing: event.rsvps.length > 0,
      }));
  }

  async create(
    ownerId: string,
    roomId: string,
    title: string,
    startsAt: number,
    durationMinutes: number,
    now: number,
  ): Promise<RoomEventView> {
    const room =
      (await this.rooms.findById(roomId)) ??
      ProtocolError.throw('ROOM_NOT_FOUND', 'Room no longer exists');
    if (room.ownerId !== ownerId)
      ProtocolError.throw('FORBIDDEN', 'Only the owner can plan events');
    if (startsAt < now - 60_000 || startsAt > now + MAX_AHEAD_MS)
      ProtocolError.throw('INVALID_PAYLOAD', 'Pick a time within 60 days');
    const upcoming = await this.prisma.roomEvent.count({
      where: { roomId, startsAt: { gte: new Date(now) } },
    });
    if (upcoming >= MAX_UPCOMING)
      ProtocolError.throw('LIMIT_REACHED', `At most ${MAX_UPCOMING} events`);
    const event = await this.prisma.roomEvent.create({
      data: {
        roomId,
        title,
        startsAt: new Date(startsAt),
        durationMinutes,
        // The organiser is going to their own event.
        rsvps: { create: { userId: ownerId } },
      },
    });
    await this.announce(roomId);
    return {
      id: event.id,
      roomId,
      title: event.title,
      startsAt: event.startsAt.getTime(),
      durationMinutes: event.durationMinutes,
      goingCount: 1,
      isGoing: true,
    };
  }

  async delete(ownerId: string, eventId: string): Promise<void> {
    const event = await this.find(eventId);
    if (event.room.ownerId !== ownerId)
      ProtocolError.throw('FORBIDDEN', 'Only the owner can cancel events');
    await this.prisma.roomEvent.delete({ where: { id: eventId } });
    await this.announce(event.roomId);
  }

  async rsvp(userId: string, eventId: string, going: boolean): Promise<void> {
    const event = await this.find(eventId);
    await this.ensureVisible(userId, event.roomId);
    if (going) {
      await this.prisma.roomEventRsvp.upsert({
        where: { eventId_userId: { eventId, userId } },
        update: {},
        create: { eventId, userId },
      });
    } else {
      await this.prisma.roomEventRsvp.deleteMany({
        where: { eventId, userId },
      });
    }
    await this.announce(event.roomId);
  }

  private async find(eventId: string) {
    return (
      (await this.prisma.roomEvent.findUnique({
        where: { id: eventId },
        select: { roomId: true, room: { select: { ownerId: true } } },
      })) ?? ProtocolError.throw('EVENT_NOT_FOUND', 'No such event')
    );
  }

  /** Public rooms are open to all but banned readers; private ones to members. */
  private async ensureVisible(userId: string, roomId: string): Promise<void> {
    const room =
      (await this.rooms.findById(roomId)) ??
      ProtocolError.throw('ROOM_NOT_FOUND', 'Room no longer exists');
    if (await this.rooms.isBanned(userId, roomId))
      ProtocolError.throw('BANNED', 'The owner removed you from this room');
    if (
      room.visibility === 'PRIVATE' &&
      !(await this.rooms.isMember(userId, roomId))
    )
      ProtocolError.throw('FORBIDDEN', 'Join this room with its code');
  }

  /** Lets everyone looking at the room reload its events. */
  private async announce(roomId: string): Promise<void> {
    await this.bus.publish(roomId, ServerEvent.roomEventsChanged, {});
  }
}
