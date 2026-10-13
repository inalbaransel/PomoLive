/** Sprite identifiers the iOS client knows how to draw. Keep in sync with `AvatarSprite` on iOS. */
export const AVATAR_SPRITE_IDS = [
  'scholar_01',
  'wizard_dev_01',
  'knight_01',
  'ranger_01',
  'bard_01',
  'robot_01',
] as const;

export type AvatarSpriteId = (typeof AVATAR_SPRITE_IDS)[number];

export const DEFAULT_AVATAR_SPRITE_ID: AvatarSpriteId = 'scholar_01';
