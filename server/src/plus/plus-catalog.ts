import { RoomTheme } from '../library/layout/library-layout.js';
import { AvatarSpriteId } from '../users/avatar-catalog.js';

/** App Store product ids of PomoLive Plus; prices are set per country in App Store Connect. */
export const PLUS_PRODUCT_IDS = [
  'com.baransel.pomolive.plus.monthly',
  'com.baransel.pomolive.plus.yearly',
] as const;

export const FREE_ROOM_LIMIT = 2;
export const PLUS_ROOM_LIMIT = 10;

/** Room looks only Plus members can pick. Classic and coffee shop stay free. */
export const PLUS_THEMES: readonly RoomTheme[] = ['forest', 'beach', 'space'];

/** Characters only Plus members can pick. */
export const PLUS_AVATARS: readonly AvatarSpriteId[] = [
  'wizard_dev_01',
  'cat_01',
  'blonde_f_01',
  'ponytail_f_01',
  'flower_f_01',
  'pink_buns_f_01',
];
