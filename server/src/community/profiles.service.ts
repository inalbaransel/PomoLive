import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { DeskStore } from '../library/desk-store.js';
import { ReaderSession } from '../library/library.service.js';
import { ModerationService } from '../moderation/moderation.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { StatsService, StatsSummary } from '../stats/stats.service.js';
import { PublicUser } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';
import { SocialService } from './social.service.js';

export interface PublicProfile extends PublicUser {
  bio: string | null;
  joinedAt: number;
  isSelf: boolean;
  /** Whether the reader shares their focus time; when not, `stats` and `focusingOn` stay empty. */
  statsVisible: boolean;
  /** The category of the desk they hold right now. */
  focusingOn: CategoryInfo | null;
  stats: StatsSummary | null;
  /** Goals are part of the focus data, so they are hidden along with it. */
  dailyGoalMinutes: number | null;
  weeklyGoalMinutes: number | null;
  isFollowing: boolean;
  /** Whether the viewer blocked this reader. */
  isBlocked: boolean;
  followerCount: number;
  followingCount: number;
}

/** A reader's profile page as another reader sees it. */
@Injectable()
export class ProfilesService {
  constructor(
    private readonly users: UsersRepository,
    private readonly stats: StatsService,
    private readonly desks: DeskStore,
    private readonly social: SocialService,
    private readonly moderation: ModerationService,
  ) {}

  async profile(viewer: ReaderSession, userId: string): Promise<PublicProfile> {
    // Someone who blocked the viewer is simply not there for them.
    const card =
      ((await this.moderation.hasBlocked(userId, viewer.user.id))
        ? null
        : await this.users.findCard(userId)) ??
      ProtocolError.throw('USER_NOT_FOUND', 'No reader with this id');
    const isSelf = userId === viewer.user.id;
    const showsStats = card.statsVisible || isSelf;
    const [stats, seat] = showsStats
      ? await Promise.all([
          this.stats.summary(userId, viewer.timeZone),
          this.desks.seatOf(userId),
        ])
      : [null, null];
    const desk = seat ? await this.desks.get(seat) : null;
    const [isFollowing, isBlocked, counts] = await Promise.all([
      this.social.isFollowing(viewer.user.id, userId),
      this.moderation.hasBlocked(viewer.user.id, userId),
      this.social.counts(userId),
    ]);

    const { createdAt, ...rest } = card;
    return {
      ...rest,
      joinedAt: createdAt.getTime(),
      isSelf,
      focusingOn: desk?.category ?? null,
      dailyGoalMinutes: showsStats ? card.dailyGoalMinutes : null,
      weeklyGoalMinutes: showsStats ? card.weeklyGoalMinutes : null,
      isFollowing,
      isBlocked,
      followerCount: counts.followers,
      followingCount: counts.following,
      stats,
    };
  }
}
