/** Sprite identifiers the iOS client knows how to draw. Keep in sync with `AvatarSprite` on iOS. */
export const AVATAR_SPRITE_IDS = [
  'scholar_01',
  'wizard_dev_01',
  'knight_01',
  'ranger_01',
  'bard_01',
  'robot_01',
  'student_f_01',
  'coder_m_01',
  'artist_f_01',
  'athlete_m_01',
  'doctor_f_01',
  'gamer_m_01',
  'scientist_f_01',
  'hijab_f_01',
  'cat_01',
  'blonde_f_01',
  'ponytail_f_01',
  'flower_f_01',
  'pink_buns_f_01',
] as const;

export type AvatarSpriteId = (typeof AVATAR_SPRITE_IDS)[number];

export const DEFAULT_AVATAR_SPRITE_ID: AvatarSpriteId = 'scholar_01';
