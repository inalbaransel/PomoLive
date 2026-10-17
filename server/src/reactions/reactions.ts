/** What a reader can leave on someone else's desk; the device draws the matching emoji. */
export const REACTIONS = ['CLAP', 'COFFEE', 'FIRE', 'STRONG', 'STAR'] as const;
export type Reaction = (typeof REACTIONS)[number];
