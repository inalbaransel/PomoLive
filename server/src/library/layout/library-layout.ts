/**
 * The hall's floor plan, sent to clients inside every room snapshot so the map is fully data-driven.
 * Coordinates are tiles; the client decides pixel size. Rows `y < WALL_HEIGHT` are the back wall.
 */
export type PropKind = 'window' | 'clock' | 'bookshelf' | 'plant' | 'coffeeMachine' | 'rug' | 'door';

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

const prop = (kind: PropKind, tileX: number, tileY: number, width: number, height: number): LayoutProp => ({
  kind,
  tileX,
  tileY,
  width,
  height,
});

function buildLayout(): LibraryLayout {
  const desks = DESK_ROWS.flatMap((tileY) => DESK_COLUMNS.map((tileX) => ({ tileX, tileY }))).map((position, index) => ({
    deskId: `desk_${index}`,
    ...position,
  }));

  const props: LayoutProp[] = [
    prop('rug', 16, 4, 6, 25),
    ...[6, 12, 24, 30].map((x) => prop('window', x, 0, 2, 2)),
    prop('clock', 18, 0, 2, 2),
    ...[2, 4, 8, 10, 26, 28, 32, 34].map((x) => prop('bookshelf', x, 3, 2, 2)),
    ...[8, 12, 16, 20, 24].flatMap((y) => [prop('bookshelf', 1, y, 2, 2), prop('bookshelf', 35, y, 2, 2)]),
    ...[
      [14, 4],
      [23, 4],
      [2, 27],
      [35, 27],
    ].map(([x, y]) => prop('plant', x, y, 1, 1)),
    prop('coffeeMachine', 4, 26, 1, 2),
    prop('door', 18, 29, 2, 1),
  ];

  return { version: 1, width: WIDTH, height: HEIGHT, wallHeight: WALL_HEIGHT, desks, props };
}

export const LIBRARY_LAYOUT: LibraryLayout = buildLayout();

const desksById = new Map(LIBRARY_LAYOUT.desks.map((desk) => [desk.deskId, desk]));

export function findLayoutDesk(deskId: string): LayoutDesk | undefined {
  return desksById.get(deskId);
}
