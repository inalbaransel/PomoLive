import { Injectable } from '@nestjs/common';
import { CategoryInfo } from '../categories/built-in-categories.js';
import { DeskStore } from '../library/desk-store.js';
import { ReaderSession } from '../library/library.service.js';
import { ProtocolError } from '../realtime/protocol-error.js';
import { StatsService, StatsSummary } from '../stats/stats.service.js';
import { PublicUser } from '../users/user.js';
import { UsersRepository } from '../users/users.repository.js';

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
}

/** A reader's profile page as another reader sees it. */
@Injectable()
export class ProfilesService {
  constructor(
    private readonly users: UsersRepository,
    private readonly stats: StatsService,
    private readonly desks: DeskStore,
  ) {}

  async profile(viewer: ReaderSession, userId: string): Promise<PublicProfile> {
    const card =
      (await this.users.findCard(userId)) ??
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

    const { createdAt, ...rest } = card;
    return {
      ...rest,
      joinedAt: createdAt.getTime(),
      isSelf,
      focusingOn: desk?.category ?? null,
      dailyGoalMinutes: showsStats ? card.dailyGoalMinutes : null,
      weeklyGoalMinutes: showsStats ? card.weeklyGoalMinutes : null,
      stats,
    };
  }
}
