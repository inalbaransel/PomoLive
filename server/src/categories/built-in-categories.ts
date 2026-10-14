/** Focus categories every reader has. Keys are stable; names and emoji are what readers see. */
export interface CategoryInfo {
  key: string;
  name: string;
  emoji: string;
}

export const BUILT_IN_CATEGORIES: readonly CategoryInfo[] = [
  { key: 'software', name: 'Yazılım', emoji: '💻' },
  { key: 'study', name: 'Ders Çalışma', emoji: '📚' },
  { key: 'reading', name: 'Okuma', emoji: '📖' },
  { key: 'writing', name: 'Yazı', emoji: '✍️' },
  { key: 'design', name: 'Tasarım', emoji: '🎨' },
  { key: 'language', name: 'Dil Öğrenme', emoji: '🗣️' },
  { key: 'work', name: 'İş', emoji: '💼' },
  { key: 'other', name: 'Diğer', emoji: '✨' },
];

export const CUSTOM_CATEGORY_PREFIX = 'custom:';
