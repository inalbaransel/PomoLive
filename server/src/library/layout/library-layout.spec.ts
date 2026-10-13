import { LIBRARY_LAYOUT } from './library-layout.js';

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

  it('never places solid props on top of a desk', () => {
    const occupied = new Set(
      LIBRARY_LAYOUT.desks.flatMap(({ tileX, tileY }) =>
        [0, 1].flatMap((dx) =>
          [0, 1].map((dy) => `${tileX + dx},${tileY + dy}`),
        ),
      ),
    );
    for (const prop of LIBRARY_LAYOUT.props.filter(
      (candidate) => candidate.kind !== 'rug',
    )) {
      for (let dx = 0; dx < prop.width; dx++) {
        for (let dy = 0; dy < prop.height; dy++)
          expect(occupied.has(`${prop.tileX + dx},${prop.tileY + dy}`)).toBe(
            false,
          );
      }
    }
  });
});
