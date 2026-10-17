import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { PrismaService } from '../infra/prisma.service.js';
import { DeskStore } from '../library/desk-store.js';
import { readTimer } from '../library/desk-timer.js';
import { RoomDirectory } from '../library/room-directory.js';
import { startOfLocalWeek } from '../library/local-day.js';
import { ModerationService } from '../moderation/moderation.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { PublicUser } from '../users/user.js';

const MAX_FOLLOWING = 200;
const SEARCH_LIMIT = 20;

const publicSelect = {
  id: true,
  username: true,
  displayName: true,
  avatarSpriteId: true,
} as const;

/** Where a followed reader is focusing right now. Private rooms stay unnamed and unjoinable. */
export interface FriendActivity {
  roomId: string | null;
  roomName: string | null;
  category: CategoryInfo;
  resting: boolean;
  /** When this desk was taken, ms epoch. */
  since: number;
}

export interface Friend {
  user: PublicUser;
  activity: FriendActivity | null;
  /** This week's focus; null when they hide their focus time. */
  weekFocusMs: number | null;
}

export interface FriendsOverview {
  /** People the reader follows, focusing ones first. */
  friends: Friend[];
  /** The reader and those who share their time, most focused this week first. */
  leaderboard: { user: PublicUser; weekFocusMs: number; isSelf: boolean }[];
}

/** Following other readers: who they are, whether they are focusing now and how their week went. */
@Injectable()
export class SocialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly desks: DeskStore,
    private readonly rooms: RoomDirectory,
    private readonly moderation: ModerationService,
  ) {}

  async follow(followerId: string, followeeId: string): Promise<void> {
    if (followerId === followeeId)
      ProtocolError.throw('FORBIDDEN', 'You cannot follow yourself');
    const exists = await this.prisma.user.count({ where: { id: followeeId } });
    if (!exists || (await this.moderation.isSeparated(followerId, followeeId)))
      ProtocolError.throw('USER_NOT_FOUND', 'No reader with this id');
    const count = await this.prisma.follow.count({ where: { followerId } });
    if (count >= MAX_FOLLOWING)
      ProtocolError.throw('LIMIT_REACHED', `At most ${MAX_FOLLOWING} follows`);
    await this.prisma.follow.upsert({
      where: { followerId_followeeId: { followerId, followeeId } },
      update: {},
      create: { followerId, followeeId },
    });
  }

  async unfollow(followerId: string, followeeId: string): Promise<void> {
    await this.prisma.follow.deleteMany({ where: { followerId, followeeId } });
  }

  /** Ids the reader follows, for delivering "started focusing" pings. */
  async followingIds(followerId: string): Promise<string[]> {
    const rows = await this.prisma.follow.findMany({
      where: { followerId },
      select: { followeeId: true },
    });
    return rows.map((row) => row.followeeId);
  }

  async isFollowing(followerId: string, followeeId: string): Promise<boolean> {
    return (
      (await this.prisma.follow.count({ where: { followerId, followeeId } })) >
      0
    );
  }

  async counts(
    userId: string,
  ): Promise<{ followers: number; following: number }> {
    const [followers, following] = await Promise.all([
      this.prisma.follow.count({ where: { followeeId: userId } }),
      this.prisma.follow.count({ where: { followerId: userId } }),
    ]);
    return { followers, following };
  }

  /** Readers whose username or name starts with `query`, excluding the searcher and blocks. */
  async search(viewerId: string, query: string): Promise<PublicUser[]> {
    const separated = await this.moderation.separatedIds(viewerId);
    return this.prisma.user.findMany({
      where: {
        id: { notIn: [viewerId, ...separated] },
        OR: [
          { username: { startsWith: query.toLowerCase() } },
          { displayName: { startsWith: query, mode: 'insensitive' } },
        ],
      },
      orderBy: { username: 'asc' },
      take: SEARCH_LIMIT,
      select: publicSelect,
    });
  }

  async overview(
    viewerId: string,
    timeZone: string,
    now: number,
  ): Promise<FriendsOverview> {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: viewerId },
      select: { followee: { select: { ...publicSelect, statsVisible: true } } },
    });
    const people = follows.map((follow) => follow.followee);
    const ids = [viewerId, ...people.map((person) => person.id)];
    const weekStart = startOfLocalWeek(now, timeZone);
    const [weekly, activities, me] = await Promise.all([
      this.prisma.focusSession.groupBy({
        by: ['userId'],
        where: { userId: { in: ids }, startedAt: { gte: weekStart } },
        _sum: { focusedMs: true },
      }),
      Promise.all(people.map((person) => this.activity(person.id, now))),
      this.prisma.user.findUniqueOrThrow({
        where: { id: viewerId },
        select: publicSelect,
      }),
    ]);
    const recorded = new Map(
      weekly.map((row) => [row.userId, row._sum.focusedMs ?? 0]),
    );
    const live = await this.activity(viewerId, now);
    const weekMs = (id: string, activity: { liveMs: number } | null) =>
      (recorded.get(id) ?? 0) + (activity?.liveMs ?? 0);

    const friends: Friend[] = people.map((person, index) => {
      const { statsVisible, ...user } = person;
      const activity = activities[index];
      return {
        user,
        activity: activity?.view ?? null,
        weekFocusMs: statsVisible ? weekMs(person.id, activity) : null,
      };
    });
    friends.sort(
      (a, b) =>
        Number(b.activity !== null) - Number(a.activity !== null) ||
        a.user.displayName.localeCompare(b.user.displayName, 'tr'),
    );

    const leaderboard = [
      { user: me, weekFocusMs: weekMs(viewerId, live), isSelf: true },
      ...friends
        .filter((friend) => friend.weekFocusMs !== null)
        .map((friend) => ({
          user: friend.user,
          weekFocusMs: friend.weekFocusMs!,
          isSelf: false,
        })),
    ].sort((a, b) => b.weekFocusMs - a.weekFocusMs);
    return { friends, leaderboard };
  }

  private async activity(
    userId: string,
    now: number,
  ): Promise<{ view: FriendActivity; liveMs: number } | null> {
    const seat = await this.desks.seatOf(userId);
    if (!seat) return null;
    const [desk, room] = await Promise.all([
      this.desks.get(seat),
      this.rooms.roomState(seat.roomId, now),
    ]);
    if (!desk) return null;
    const reading = readTimer(desk.timer, now);
    const joinable = room !== null && room.kind !== 'PRIVATE';
    return {
      view: {
        roomId: joinable ? seat.roomId : null,
        roomName: joinable ? room.name : null,
        category: desk.category,
        resting: reading.phase === 'BREAK',
        since: desk.startedAt,
      },
      liveMs: reading.focusedMs,
    };
  }
}
