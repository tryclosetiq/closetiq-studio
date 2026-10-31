import assert from "node:assert/strict";
import { test } from "node:test";
import { Image } from "imagescript";
import { cellRect, gridSpec, MAX_GARMENTS } from "../supabase/functions/_shared/garment_grid.mjs";
import { composeGarmentGrid } from "../supabase/functions/_shared/compose_grid.mjs";
import { FLUX_STUDIO_CREDITS, fluxPrompt } from "../supabase/functions/_shared/flux_prompt.mjs";
import { mkdir, writeFile } from "node:fs/promises";

test("grid is 2 columns of 512, and a single item is a 1024 cell", () => {
  assert.equal(MAX_GARMENTS, 4);
  assert.deepEqual(
    { ...gridSpec(1), pad: gridSpec(1).pad },
    { count: 1, cols: 1, rows: 1, cell: 1024, width: 1024, height: 1024, pad: 32 },
  );
  assert.deepEqual(gridSpec(2), { count: 2, cols: 2, rows: 1, cell: 512, width: 1024, height: 512, pad: 16 });
  assert.deepEqual(gridSpec(3), { count: 3, cols: 2, rows: 2, cell: 512, width: 1024, height: 1024, pad: 16 });
  assert.deepEqual(gridSpec(4), { count: 4, cols: 2, rows: 2, cell: 512, width: 1024, height: 1024, pad: 16 });
  assert.throws(() => gridSpec(5));
  assert.throws(() => gridSpec(0));
});

test("cells are row-major and contain-fit inside the padding", () => {
  const spec = gridSpec(4);
  assert.deepEqual(cellRect(0, spec), { x: 0, y: 0, size: 512, pad: 16, inner: 480 });
  assert.deepEqual(cellRect(1, spec), { x: 512, y: 0, size: 512, pad: 16, inner: 480 });
  assert.deepEqual(cellRect(3, spec), { x: 512, y: 512, size: 512, pad: 16, inner: 480 });
});

async function solid(width, height, color) {
  const img = new Image(width, height);
  img.fill(color);
  return await img.encode();
}

function rgba(img, x, y) {
  const px = img.getRGBAAt(x, y);
  return [px[0], px[1], px[2], px[3]];
}
function near(actual, expected) {
  assert.equal(actual.length, expected.length);
  actual.forEach((channel, i) => assert.ok(Math.abs(channel - expected[i]) <= 8, `${actual} vs ${expected}`));
}

test("merged grid puts each garment in its cell and leaves an empty cell white", async () => {
  const bytes = await Promise.all([
    solid(80, 140, 0xff0000ff),
    solid(140, 40, 0x00aa00ff),
    solid(30, 30, 0x0000ffff),
    solid(200, 20, 0xffcc00ff),
  ]);
  const four = await composeGarmentGrid(bytes, Image);
  assert.equal(four.spec.width, 1024);
  assert.equal(four.spec.height, 1024);
  const decoded = await Image.decode(four.bytes);
  assert.equal(decoded.width, 1024);
  assert.equal(decoded.height, 1024);
  near(rgba(decoded, 257, 257), [255, 0, 0, 255]);
  near(rgba(decoded, 769, 257), [0, 170, 0, 255]);
  near(rgba(decoded, 257, 769), [0, 0, 255, 255]);
  near(rgba(decoded, 769, 769), [255, 204, 0, 255]);

  const three = await composeGarmentGrid(bytes.slice(0, 3), Image);
  const threeImg = await Image.decode(three.bytes);
  near(rgba(threeImg, 257, 769), [0, 0, 255, 255]);
  near(rgba(threeImg, 769, 769), [255, 255, 255, 255]);

  const pair = await composeGarmentGrid(bytes.slice(0, 2), Image);
  assert.equal(pair.spec.width, 1024);
  assert.equal(pair.spec.height, 512);

  const wide = await composeGarmentGrid([await solid(200, 20, 0xff0000ff)], Image);
  const wideImg = await Image.decode(wide.bytes);
  assert.equal(wideImg.width, 1024);
  near(rgba(wideImg, 513, 80), [255, 255, 255, 255]);
  near(rgba(wideImg, 513, 512), [255, 0, 0, 255]);

  await mkdir("/opt/cursor/artifacts", { recursive: true });
  await writeFile("/opt/cursor/artifacts/garment-grid-4.jpg", four.bytes);
  await writeFile("/opt/cursor/artifacts/garment-grid-3.jpg", three.bytes);
  await writeFile("/opt/cursor/artifacts/garment-grid-2.jpg", pair.bytes);
});

test("prompt names every garment and keeps a fit phrase", () => {
  assert.equal(FLUX_STUDIO_CREDITS, 1);
  const prompt = fluxPrompt([
    { name: "Olive oversized bomber", notes: "" },
    { name: "Black wide-leg trousers", notes: "" },
  ], { instructions: "keep the mirror", keepFit: true });
  assert.match(prompt, /^The person of image 1, maintaining exactly their face and pose, wearing /);
  assert.match(prompt, /Olive oversized bomber/);
  assert.match(prompt, /oversized and loose/);
  assert.match(prompt, /wide-leg trousers/);
  assert.match(prompt, /wide, loose legs/);
  assert.match(prompt, /of image 2\./);
  assert.match(prompt, /keep the mirror$/);
  const plain = fluxPrompt([{ name: "Tee" }], { keepFit: false, instructions: "" });
  assert.equal(plain, "The person of image 1, maintaining exactly their face and pose, wearing the Tee of image 2.");
});
