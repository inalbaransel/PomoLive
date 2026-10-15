/**
 * The hall's floor plan, sent to clients inside every room snapshot so the map is fully data-driven.
 * Coordinates are tiles; the client decides pixel size. Rows `y < WALL_HEIGHT` are the back wall.
 */
export type PropKind =
  // Library and café
  | 'window'
  | 'clock'
  | 'bookshelf'
  | 'plant'
  | 'coffeeMachine'
  | 'rug'
  | 'door'
  | 'neonSign'
  | 'chalkboard'
  | 'coffeeBar'
  // Forest
  | 'path'
  | 'tree'
  | 'bush'
  | 'flowers'
  | 'mushroom'
  | 'campfire'
  | 'stump'
  | 'pond'
  // Space shuttle
  | 'walkway'
  | 'porthole'
  | 'viewscreen'
  | 'console'
  | 'crate'
  | 'hologram'
  | 'airlock'
  // Beach
  | 'boardwalk'
  | 'palm'
  | 'umbrella'
  | 'towel'
  | 'sandcastle'
  | 'shell'
  | 'surfboard';

/** The look of a room. Every theme shares the same desks, so a desk id means the same seat everywhere. */
export const ROOM_THEMES = [
  'classic',
  'coffee_shop',
  'forest',
  'space',
  'beach',
] as const;
export type RoomTheme = (typeof ROOM_THEMES)[number];

export interface LayoutDesk {
  deskId: string;
  tileX: number;
  tileY: number;
}

export interface LayoutProp {
  kind: PropKind;
  tileX: number;
  tileY: number;
  width: number;
  height: number;
}

export interface LibraryLayout {
  version: number;
  theme: RoomTheme;
  width: number;
  height: number;
  wallHeight: number;
  desks: LayoutDesk[];
  props: LayoutProp[];
}

const WIDTH = 38;
const HEIGHT = 30;
const WALL_HEIGHT = 3;
const DESK_COLUMNS = [5, 9, 13, 23, 27, 31];
const DESK_ROWS = [7, 11, 15, 19, 23];

const prop = (
  kind: PropKind,
  tileX: number,
  tileY: number,
  width: number,
  height: number,
): LayoutProp => ({
  kind,
  tileX,
  tileY,
  width,
  height,
});

function buildDesks(): LayoutDesk[] {
  return DESK_ROWS.flatMap((tileY) =>
    DESK_COLUMNS.map((tileX) => ({ tileX, tileY })),
  ).map((position, index) => ({
    deskId: `desk_${index}`,
    ...position,
  }));
}

function layout(theme: RoomTheme, props: LayoutProp[]): LibraryLayout {
  return {
    version: 1,
    theme,
    width: WIDTH,
    height: HEIGHT,
    wallHeight: WALL_HEIGHT,
    desks: buildDesks(),
    props,
  };
}

/** `[x, y]` pairs to 1×1 props of one kind. */
const scatter = (kind: PropKind, spots: number[][]): LayoutProp[] =>
  spots.map(([x, y]) => prop(kind, x, y, 1, 1));

function buildLibraryLayout(): LibraryLayout {
  const props: LayoutProp[] = [
    prop('rug', 16, 4, 6, 25),
    ...[6, 12, 24, 30].map((x) => prop('window', x, 0, 2, 2)),
    prop('clock', 18, 0, 2, 2),
    ...[2, 4, 8, 10, 26, 28, 32, 34].map((x) => prop('bookshelf', x, 3, 2, 2)),
    ...[8, 12, 16, 20, 24].flatMap((y) => [
      prop('bookshelf', 1, y, 2, 2),
      prop('bookshelf', 35, y, 2, 2),
    ]),
    ...[
      [14, 4],
      [23, 4],
      [2, 27],
      [35, 27],
    ].map(([x, y]) => prop('plant', x, y, 1, 1)),
    prop('coffeeMachine', 4, 26, 1, 2),
    prop('door', 18, 29, 2, 1),
  ];
  return layout('classic', props);
}

function buildCoffeeShopLayout(): LibraryLayout {
  const props: LayoutProp[] = [
    // Warm cafe runner rug in the center aisle
    prop('rug', 16, 4, 6, 25),
    // Glowing neon sign at center top of the brick wall
    prop('neonSign', 17, 0, 4, 2),
    // Cozy nighttime cafe windows
    ...[6, 30].map((x) => prop('window', x, 0, 2, 2)),
    // Vintage cafe clock
    prop('clock', 12, 0, 2, 2),
    // Chalkboard menu on the back brick wall
    prop('chalkboard', 24, 0, 3, 2),
    // Side bookshelves holding vinyls, books and mugs
    ...[8, 14, 20].flatMap((y) => [
      prop('bookshelf', 1, y, 2, 2),
      prop('bookshelf', 35, y, 2, 2),
    ]),
    // Coffee bar counter and espresso machine
    prop('coffeeBar', 1, 25, 4, 3),
    prop('coffeeMachine', 3, 26, 1, 2),
    // Cozy indoor plants
    ...[
      [14, 4],
      [23, 4],
      [1, 5],
      [35, 5],
      [2, 27],
      [35, 27],
    ].map(([x, y]) => prop('plant', x, y, 1, 1)),
    // Entrance doors
    prop('door', 18, 29, 2, 1),
  ];
  return layout('coffee_shop', props);
}

/** A clearing in the woods: a dirt path, trees along the edges, a campfire and a pond. */
function buildForestLayout(): LibraryLayout {
  const props: LayoutProp[] = [
    prop('path', 16, 3, 6, 27),
    ...[4, 8, 12, 16, 20].flatMap((y) => [
      prop('tree', 1, y, 2, 3),
      prop('tree', 35, y, 2, 3),
    ]),
    ...[3, 10, 25, 32].map((x) => prop('bush', x, 3, 2, 2)),
    ...scatter('flowers', [
      [7, 4],
      [12, 5],
      [15, 9],
      [22, 13],
      [26, 5],
      [30, 4],
      [8, 21],
      [30, 14],
    ]),
    ...scatter('mushroom', [
      [11, 10],
      [26, 14],
      [7, 18],
      [30, 22],
      [12, 26],
    ]),
    prop('campfire', 2, 25, 2, 2),
    ...[
      [11, 13],
      [25, 9],
      [29, 17],
      [7, 9],
    ].map(([x, y]) => prop('bush', x, y, 2, 2)),
    ...scatter('stump', [
      [1, 27],
      [4, 25],
      [4, 27],
    ]),
    prop('pond', 31, 25, 4, 3),
    prop('tree', 35, 25, 2, 3),
  ];
  return layout('forest', props);
}

/** A shuttle's study deck: portholes onto the stars, consoles along the hull, an airlock aft. */
function buildSpaceLayout(): LibraryLayout {
  const props: LayoutProp[] = [
    prop('walkway', 16, 3, 6, 26),
    prop('viewscreen', 15, 0, 8, 2),
    ...[3, 8, 27, 32].map((x) => prop('porthole', x, 0, 2, 2)),
    ...[8, 12, 16, 20].flatMap((y) => [
      prop('console', 1, y, 2, 2),
      prop('console', 35, y, 2, 2),
    ]),
    ...scatter('crate', [
      [2, 4],
      [3, 4],
      [34, 4],
      [35, 5],
      [2, 26],
      [11, 13],
      [12, 13],
      [25, 21],
      [29, 9],
    ]),
    prop('hologram', 33, 25, 3, 3),
    ...scatter('plant', [
      [11, 4],
      [26, 4],
      [4, 27],
    ]),
    prop('airlock', 17, 28, 4, 2),
  ];
  return layout('space', props);
}

/** A study spot on the sand: the sea along the top, a boardwalk, palms, umbrellas and towels. */
function buildBeachLayout(): LibraryLayout {
  const props: LayoutProp[] = [
    prop('boardwalk', 16, 3, 6, 27),
    ...[5, 11, 17].flatMap((y) => [
      prop('palm', 1, y, 2, 3),
      prop('palm', 35, y, 2, 3),
    ]),
    prop('umbrella', 3, 3, 2, 2),
    prop('umbrella', 31, 3, 2, 2),
    prop('umbrella', 2, 24, 2, 2),
    // Between the desks, in the gaps of the grid.
    prop('umbrella', 11, 9, 2, 2),
    prop('umbrella', 25, 17, 2, 2),
    prop('umbrella', 7, 21, 2, 2),
    prop('towel', 7, 4, 2, 1),
    prop('towel', 26, 4, 2, 1),
    prop('towel', 25, 10, 2, 1),
    prop('towel', 11, 18, 2, 1),
    prop('towel', 29, 22, 2, 1),
    prop('surfboard', 35, 23, 1, 3),
    prop('surfboard', 36, 24, 1, 3),
    prop('sandcastle', 30, 26, 2, 2),
    ...scatter('shell', [
      [12, 5],
      [25, 6],
      [11, 13],
      [26, 17],
      [8, 26],
      [14, 27],
      [24, 27],
    ]),
  ];
  return layout('beach', props);
}

export const LIBRARY_LAYOUT: LibraryLayout = buildLibraryLayout();

/** Every floor plan by theme, so room cards and the room editor can preview each look. */
export const LAYOUTS_BY_THEME: Record<RoomTheme, LibraryLayout> = {
  classic: LIBRARY_LAYOUT,
  coffee_shop: buildCoffeeShopLayout(),
  forest: buildForestLayout(),
  space: buildSpaceLayout(),
  beach: buildBeachLayout(),
};

export function getLayoutForTheme(theme?: string): LibraryLayout {
  return LAYOUTS_BY_THEME[theme as RoomTheme] ?? LIBRARY_LAYOUT;
}

const desksById = new Map(
  LIBRARY_LAYOUT.desks.map((desk) => [desk.deskId, desk]),
);

export function findLayoutDesk(deskId: string): LayoutDesk | undefined {
  return desksById.get(deskId);
}
