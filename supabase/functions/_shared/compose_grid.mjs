import { cellRect, gridSpec } from "./garment_grid.mjs";

const WHITE = 0xffffffff;
const MAX_PERSON_PIXELS = 4_000_000;

// Image is imagescript's Image class, passed in so this file can run under Node and Deno.
export async function composeGarmentGrid(byteList, Image) {
  if (!byteList?.length) throw new Error("No garment photos to merge.");
  const spec = gridSpec(byteList.length);
  const canvas = new Image(spec.width, spec.height);
  canvas.fill(WHITE);
  for (let i = 0; i < byteList.length; i++) {
    const img = await Image.decode(byteList[i]);
    const rect = cellRect(i, spec);
    const fitted = img.clone().fit(rect.inner, rect.inner);
    canvas.composite(fitted, rect.x + rect.pad, rect.y + rect.pad);
  }
  const bytes = await canvas.encodeJPEG(90);
  return { bytes, spec, mime: "image/jpeg" };
}

// Keep the person photo at or under 4 megapixels so vto-v2 uses it as-is
// (larger inputs are downscaled by BFL to about 1 megapixel).
export async function preparePerson(bytes, Image) {
  try {
    const img = await Image.decode(bytes);
    const pixels = img.width * img.height;
    if (pixels > MAX_PERSON_PIXELS) {
      const scale = Math.sqrt(MAX_PERSON_PIXELS / pixels);
      img.resize(Math.max(1, Math.round(img.width * scale)), Math.max(1, Math.round(img.height * scale)));
    }
    return await img.encodeJPEG(90);
  } catch {
    return bytes;
  }
}

export function bytesToBase64(bytes) {
  const chunk = 8192;
  let bin = "";
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}
