/**
 * Read a product page's public metadata (Open Graph, Twitter, JSON-LD).
 * No network. The import function fetches the page, then calls this.
 */

const RESERVED_HOSTS = new Set(["localhost", "metadata.google.internal"]);

export function assertPublicHttpsUrl(raw) {
  let url;
  try {
    url = new URL(String(raw || "").trim());
  } catch {
    throw new Error("That doesn't look like a valid URL.");
  }
  if (url.username || url.password) {
    throw new Error("Links with a username or password can't be imported.");
  }
  if (url.protocol !== "https:") {
    throw new Error("Only https links can be imported.");
  }
  const host = url.hostname.toLowerCase().replace(/\.+$/, "");
  if (!host || RESERVED_HOSTS.has(host) || host.endsWith(".local") || host.endsWith(".internal") || host.endsWith(".localhost")) {
    throw new Error("That link can't be imported.");
  }
  if (isIp(host) && !isPublicIp(host)) {
    throw new Error("That link can't be imported.");
  }
  return url;
}

export function extractProductMeta(html, pageUrl) {
  const text = String(html || "");
  const base = safeUrl(pageUrl);
  const ld = readJsonLd(text);
  const ogTitle = metaContent(text, "og:title") || metaContent(text, "twitter:title");
  const docTitle = titleTag(text);
  const name = clean(ld.name || ogTitle || docTitle);
  const imageUrl = resolveUrl(ld.image || metaContent(text, "og:image") || metaContent(text, "twitter:image"), base);
  const amount = ld.price || metaContent(text, "product:price:amount") || metaContent(text, "og:price:amount");
  const currency = (ld.currency || metaContent(text, "product:price:currency") || metaContent(text, "og:price:currency") || "").toUpperCase();
  const priceText = formatPrice(amount, currency);
  return {
    name: name || null,
    imageUrl,
    priceText,
    currency: currency || null,
    hasAny: Boolean(name || imageUrl || priceText),
  };
}

function safeUrl(value) {
  try {
    return new URL(value);
  } catch {
    return null;
  }
}

function clean(value) {
  return decodeEntities(String(value || ""))
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 200);
}

function decodeEntities(value) {
  return value
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => safeChar(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, n) => safeChar(parseInt(n, 10)))
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");
}

function safeChar(code) {
  if (!Number.isFinite(code) || code < 32 || code > 0x10ffff) return "";
  return String.fromCodePoint(code);
}

function metaContent(html, key) {
  const tags = html.match(/<meta\b[^>]*>/gi) || [];
  const attr = key.includes(":") || key.startsWith("og") || key.startsWith("twitter") || key.startsWith("product") ? "property" : "name";
  for (const tag of tags) {
    const property = attrValue(tag, "property") || attrValue(tag, "name");
    if ((property || "").toLowerCase() !== key.toLowerCase()) continue;
    const content = attrValue(tag, "content");
    if (content) return decodeEntities(content).trim();
  }
  // Some pages only set name= for product tags.
  if (attr === "property") {
    for (const tag of tags) {
      const property = attrValue(tag, "name");
      if ((property || "").toLowerCase() !== key.toLowerCase()) continue;
      const content = attrValue(tag, "content");
      if (content) return decodeEntities(content).trim();
    }
  }
  return "";
}

function attrValue(tag, name) {
  const re = new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, "i");
  const m = tag.match(re);
  return (m && (m[1] ?? m[2] ?? m[3])) || "";
}

function titleTag(html) {
  const m = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return m ? m[1] : "";
}

function readJsonLd(html) {
  const out = { name: "", image: "", price: "", currency: "" };
  const blocks = html.match(/<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>[\s\S]*?<\/script>/gi) || [];
  for (const block of blocks) {
    const body = block.replace(/^[\s\S]*?>/, "").replace(/<\/script>\s*$/i, "");
    try {
      absorb(JSON.parse(body), out);
    } catch {
      // Ignore broken JSON-LD. Open Graph can still fill the form.
    }
    if (out.name && out.image && out.price) break;
  }
  return out;
}

function absorb(node, out) {
  if (!node) return;
  if (Array.isArray(node)) {
    node.forEach((item) => absorb(item, out));
    return;
  }
  if (typeof node !== "object") return;
  if (node["@graph"]) absorb(node["@graph"], out);
  const type = node["@type"];
  const types = (Array.isArray(type) ? type : [type]).filter(Boolean).map((t) => String(t).toLowerCase());
  if (types.includes("product")) {
    if (!out.name && node.name) out.name = String(node.name);
    if (!out.image) out.image = imageOf(node.image);
    const offer = Array.isArray(node.offers) ? node.offers[0] : node.offers;
    if (offer && typeof offer === "object") {
      if (!out.price) out.price = String(offer.price ?? offer.lowPrice ?? "");
      if (!out.currency && offer.priceCurrency) out.currency = String(offer.priceCurrency);
    }
  }
  for (const value of Object.values(node)) {
    if (value && typeof value === "object") absorb(value, out);
  }
}

function imageOf(image) {
  if (!image) return "";
  if (typeof image === "string") return image;
  if (Array.isArray(image)) return imageOf(image[0]);
  if (typeof image === "object" && image.url) return String(image.url);
  return "";
}

function resolveUrl(value, base) {
  const raw = clean(value);
  if (!raw || !base) return null;
  try {
    const url = new URL(raw, base);
    if (url.protocol !== "https:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function formatPrice(amount, currency) {
  const raw = String(amount || "").trim().replace(/,/g, "");
  if (!raw) return null;
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0 || value > 1000000) return null;
  const fixed = raw.includes(".") || !Number.isInteger(value) ? value.toFixed(2) : String(value);
  if (!currency || currency === "USD") return `$${fixed}`;
  return `${currency} ${fixed}`;
}

function isIp(host) {
  return /^\d{1,3}(\.\d{1,3}){3}$/.test(host) || host.includes(":");
}

function isPublicIp(host) {
  if (host.includes(":")) {
    const h = host.toLowerCase();
    if (h === "::1" || h === "::") return false;
    if (h.startsWith("fe80:") || h.startsWith("fc") || h.startsWith("fd")) return false;
    return true;
  }
  const parts = host.split(".").map((n) => Number(n));
  if (parts.some((n) => n > 255)) return false;
  const [a, b] = parts;
  if (a === 10 || a === 127 || a === 0) return false;
  if (a === 169 && b === 254) return false;
  if (a === 172 && b >= 16 && b <= 31) return false;
  if (a === 192 && b === 168) return false;
  if (a === 100 && b >= 64 && b <= 127) return false;
  return true;
}
