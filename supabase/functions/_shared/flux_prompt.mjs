// Studio credit charged for one successful FLUX VTO v2 image (1–4 garments, one call).
// BFL lists Virtual Try-On at about $0.0475 per image (1 BFL credit = $0.01).
// A FASHN credit is $0.075 on demand, so 1 studio credit is the smallest whole credit
// that stays at or above the BFL price. It is cheaper than Studio's default HD preset
// (Try-On Max balanced 1K = 2 FASHN credits, $0.15). Item count does not raise the price,
// because BFL bills the merged image once. Failed or moderated runs are not charged here.
export const FLUX_STUDIO_CREDITS = 1;

// Same fit phrases as the Try-On tab. The name and notes are the only fit signal.
const FIT_RULES = [
  [/\b(oversized?|baggy|boxy|slouchy|loose(-| )?fit(ting)?|loose)\b/, "oversized and loose: dropped shoulders, roomy wide sleeves, boxy body with extra fabric, full long hem — baggy, not fitted"],
  [/\b(relaxed|boyfriend|easy[- ]fit)\b/, "relaxed, easy fit with room through the body — not tight"],
  [/\b(fitted|slim(-| )?fit|bodycon|body[- ]?hugging|form[- ]?fitting|skinny|tight|snug)\b/, "fitted and close to the body"],
  [/\b(wide(-| )?leg|palazzo|flared?|bootcut|bell[- ]bottoms?)\b/, "wide, loose legs falling from the hip to the floor"],
  [/\bstraight(-| )?leg\b/, "straight legs, not tapered"],
  [/\b(cropped?|crop[- ]top)\b/, "cropped: a short hem ending above the natural waist for a top, or above the ankle for pants"],
  [/\b(longline|tunic|elongated)\b/, "longline, hem falling well below the hip"],
  [/\bhigh[- ]?(waist|waisted|rise)\b/, "high-waisted, sitting at the natural waist"],
  [/\bmaxi\b/, "maxi, floor-length", /skirt|dress/],
  [/\bmidi\b/, "midi, mid-calf length", /skirt|dress/],
  [/\bmini\b/, "mini, short above the knee", /skirt|dress/],
];

export function cleanText(value) {
  return String(value ?? "").replace(/[\u0000-\u001f]+/g, " ").replace(/\s+/g, " ").trim();
}

export function fitParts(g) {
  if (!g) return [];
  const text = `${g.name || ""} ${g.notes || ""}`.toLowerCase();
  return FIT_RULES.filter(([re, , need]) => re.test(text) && (!need || need.test(text))).map(([, phrase]) => phrase);
}

// BFL's formula: "The person of image 1, maintaining exactly their face and pose, wearing the {garments} of image 2."
export function fluxPrompt(garments, { instructions = "", keepFit = true } = {}) {
  const bits = garments.map((g) => {
    const name = cleanText(g?.name) || "garment";
    const fit = keepFit ? fitParts(g) : [];
    return fit.length ? `the ${name} (${fit.join("; ")})` : `the ${name}`;
  });
  const list = bits.length === 1 ? bits[0] : `${bits.slice(0, -1).join(", ")} and ${bits[bits.length - 1]}`;
  const formula = `The person of image 1, maintaining exactly their face and pose, wearing ${list} of image 2.`;
  const extra = cleanText(instructions).slice(0, 500);
  return [formula, extra].filter(Boolean).join(" ").slice(0, 1500);
}
