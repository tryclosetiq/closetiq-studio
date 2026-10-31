// Layout for a FLUX VTO garment reference.
// Mirrors ClosetIQ's collage: a 2-column grid of 512px cells, one cell per garment,
// sent as a single "complete outfit" image. BFL recommends at most about 4 garments.
// A single item uses a 1024px cell (~1 megapixel) so a lone product photo keeps its detail.
// Two or more items use 512px cells: 2 → 1024×512, 3–4 → 1024×1024.

export const MAX_GARMENTS = 4;
export const CELL = 512;
export const SINGLE_CELL = 1024;

export function gridSpec(count) {
  if (!Number.isInteger(count) || count < 1 || count > MAX_GARMENTS) {
    throw new Error(`FLUX try-on accepts 1 to ${MAX_GARMENTS} items.`);
  }
  if (count === 1) {
    return { count, cols: 1, rows: 1, cell: SINGLE_CELL, width: SINGLE_CELL, height: SINGLE_CELL, pad: 32 };
  }
  const cols = 2;
  const rows = Math.ceil(count / cols);
  return { count, cols, rows, cell: CELL, width: cols * CELL, height: rows * CELL, pad: 16 };
}

// Cell origin and the inner box the garment is contain-fitted into.
export function cellRect(index, spec) {
  if (!Number.isInteger(index) || index < 0 || index >= spec.count) {
    throw new Error("Garment index is outside the grid.");
  }
  const col = index % spec.cols;
  const row = Math.floor(index / spec.cols);
  const pad = spec.pad;
  return {
    x: col * spec.cell,
    y: row * spec.cell,
    size: spec.cell,
    pad,
    inner: spec.cell - pad * 2,
  };
}
