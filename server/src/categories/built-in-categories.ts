import { Glyph } from '../common/glyph.js';

/** Focus categories every reader has. Keys are stable; names and glyphs are what readers see. */
export interface CategoryInfo extends Glyph {
  key: string;
  name: string;
}

export const BUILT_IN_CATEGORIES: readonly CategoryInfo[] = [
  {
    key: 'software',
    name: 'Yazılım',
    symbol: 'chevron.left.forwardslash.chevron.right',
    color: 'blue',
  },
  {
    key: 'study',
    name: 'Ders Çalışma',
    symbol: 'graduationcap.fill',
    color: 'orange',
  },
  { key: 'reading', name: 'Okuma', symbol: 'book.fill', color: 'brown' },
  { key: 'writing', name: 'Yazı', symbol: 'pencil.line', color: 'purple' },
  {
    key: 'design',
    name: 'Tasarım',
    symbol: 'paintpalette.fill',
    color: 'pink',
  },
  {
    key: 'language',
    name: 'Dil Öğrenme',
    symbol: 'character.bubble.fill',
    color: 'teal',
  },
  { key: 'work', name: 'İş', symbol: 'briefcase.fill', color: 'gray' },
  {
    key: 'other',
    name: 'Diğer',
    symbol: 'square.grid.2x2.fill',
    color: 'indigo',
  },
];

export const CUSTOM_CATEGORY_PREFIX = 'custom:';
