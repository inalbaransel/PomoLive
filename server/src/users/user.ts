/** What other readers see of someone: in a hall, a member list or on a profile. */
export interface PublicUser {
  id: string;
  username: string;
  displayName: string;
  avatarSpriteId: string;
}

/** The signed-in reader's own account, including their settings. */
export interface UserProfile extends PublicUser {
  bio: string | null;
  statsVisible: boolean;
}

export type ProfileChanges = Partial<Omit<UserProfile, 'id'>>;
