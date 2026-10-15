import { LAYOUTS_BY_THEME, LIBRARY_LAYOUT } from './library-layout.js';

/** Props drawn flat on the ground, which desks may stand next to or on. */
const GROUND_COVERS = new Set(['rug', 'path', 'walkway', 'boardwalk']);

describe('LIBRARY_LAYOUT', () => {
  it('has 30 uniquely numbered desks inside the floor area', () => {
    const { desks, width, height, wallHeight } = LIBRARY_LAYOUT;
    expect(desks).toHaveLength(30);
    expect(new Set(desks.map((desk) => desk.deskId)).size).toBe(30);
    for (const desk of desks) {
      expect(desk.tileX).toBeGreaterThan(0);
      expect(desk.tileX + 1).toBeLessThan(width - 1);
      expect(desk.tileY).toBeGreaterThanOrEqual(wallHeight);
      expect(desk.tileY + 1).toBeLessThan(height - 1);
    }
  });
});

describe.each(Object.entries(LAYOUTS_BY_THEME))(
  '%s layout',
  (theme, layout) => {
    it('names its theme and keeps the shared desks', () => {
      expect(layout.theme).toBe(theme);
      expect(layout.desks).toEqual(LIBRARY_LAYOUT.desks);
    });

    it('keeps every prop inside the map and off the desks', () => {
      const occupied = new Set(
        layout.desks.flatMap(({ tileX, tileY }) =>
          [0, 1].flatMap((dx) =>
            [0, 1].map((dy) => `${tileX + dx},${tileY + dy}`),
          ),
        ),
      );
      for (const prop of layout.props) {
        expect(prop.tileX).toBeGreaterThanOrEqual(0);
        expect(prop.tileY).toBeGreaterThanOrEqual(0);
        expect(prop.tileX + prop.width).toBeLessThanOrEqual(layout.width);
        expect(prop.tileY + prop.height).toBeLessThanOrEqual(layout.height);
        if (GROUND_COVERS.has(prop.kind)) continue;
        for (let dx = 0; dx < prop.width; dx++) {
          for (let dy = 0; dy < prop.height; dy++)
            expect(
              occupied.has(`${prop.tileX + dx},${prop.tileY + dy}`),
              `${prop.kind} at ${prop.tileX},${prop.tileY}`,
            ).toBe(false);
        }
      }
    });
  },
);
