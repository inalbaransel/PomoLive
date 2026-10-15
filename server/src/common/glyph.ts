/**
 * Icons for rooms and categories: an SF Symbol on a colored circle, like Reminders lists.
 * Both lists are closed so every client can draw every glyph. Keep in sync with `Glyph.swift` on iOS.
 */
export const GLYPH_COLORS = [
  'red',
  'orange',
  'yellow',
  'green',
  'mint',
  'teal',
  'blue',
  'indigo',
  'purple',
  'pink',
  'brown',
  'gray',
] as const;

export const GLYPH_SYMBOLS = [
  'chevron.left.forwardslash.chevron.right',
  'laptopcomputer',
  'graduationcap.fill',
  'book.fill',
  'books.vertical.fill',
  'pencil.line',
  'paintpalette.fill',
  'character.bubble.fill',
  'briefcase.fill',
  'square.grid.2x2.fill',
  'brain.head.profile.fill',
  'lightbulb.fill',
  'function',
  'flask.fill',
  'atom',
  'globe.europe.africa.fill',
  'music.note',
  'guitars.fill',
  'pianokeys',
  'camera.fill',
  'headphones',
  'chart.bar.fill',
  'leaf.fill',
  'moon.stars.fill',
  'sun.max.fill',
  'cup.and.saucer.fill',
  'flame.fill',
  'bolt.fill',
  'target',
  'star.fill',
  'heart.fill',
  'figure.run',
  'dumbbell.fill',
  'building.columns.fill',
  'house.fill',
  'sparkles',
] as const;

export type GlyphColor = (typeof GLYPH_COLORS)[number];
export type GlyphSymbol = (typeof GLYPH_SYMBOLS)[number];

export interface Glyph {
  symbol: string;
  color: string;
}
