// Picture shown on a public storefront tile. shop.html and the Studio editor both use this.
// The look page itself always uses collage_public_path.
// A custom shop image (custom.jpg), or any hero that is not the cover file, wins over the
// auto product grid. An AI-photo cover (cover.jpg) stays ahead of that grid.
// Empty cover_public_path still shows the hero, so a look is not left as a blank tile.
// Amazon store hosts (amazon.com, amazon.co.uk, …) and official short-link hosts.
// Short links are valid as-is: link.amazon, amzn.to, amzn.eu, a.co, amzlink.to.
function isAmazonHost(host) {
  host = String(host || "").toLowerCase().replace(/\.$/, "");
  if (host === "link.amazon" || host.endsWith(".link.amazon")) return "short";
  if (host === "a.co" || host.endsWith(".a.co")) return "short";
  if (host === "amzlink.to" || host.endsWith(".amzlink.to")) return "short";
  if (/(^|\.)amzn\.(to|com|eu|asia|in)$/.test(host)) return "short";
  if (/(^|\.)amazon\.[a-z.]+$/.test(host)) return "store";
  return "";
}
function isAmazonLink(u) {
  try {
    const url = new URL(String(u || "").trim());
    return url.protocol === "https:" && !url.username && !url.password && isAmazonHost(url.hostname) !== "";
  } catch { return false; }
}
// Retailer and affiliate hosts that may appear on a find or a look, besides Amazon.
// Matching is the host itself or a subdomain, so tkqlhce.com.evil.com does not pass.
const AFFILIATE_HOSTS = [
  "tkqlhce.com", "anrdoezrs.net", "dpbolvw.net", "jdoqocy.com", "kqzyfj.com", "emjcd.com",
  "dreampairs.com", "shareasale.com", "rstyle.me", "shopstyle.it", "go.skimresources.com",
  "linksynergy.com", "awin1.com", "liketk.it", "shopltk.com", "ltk.com", "howl.me", "sjv.io", "pxf.io",
];
function isAffiliateHost(host) {
  host = String(host || "").toLowerCase().replace(/\.$/, "");
  return AFFILIATE_HOSTS.some((root) => host === root || host.endsWith("." + root));
}
function isShopLink(u) {
  if (isAmazonLink(u)) return true;
  try {
    const url = new URL(String(u || "").trim());
    if (url.protocol !== "https:" || url.username || url.password) return false;
    return isAffiliateHost(url.hostname);
  } catch { return false; }
}
function shopButtonLabel(url, brand) {
  if (isAmazonLink(url)) return "Shop on Amazon";
  const name = String(brand || "").trim();
  return name ? "Shop at " + name : "Shop now";
}
function affiliateDisclosure(text, hasOther) {
  const base = String(text || "").trim();
  const extra = "I may earn a commission from other affiliate links.";
  if (!hasOther || base.includes(extra)) return base;
  return base ? base + " " + extra : extra;
}
function shopTilePath(row) {
  const hero = (row && row.collage_public_path) || "";
  const cover = (row && row.cover_public_path) || "";
  if (hero && hero !== cover && !/\/cover\.jpg$/i.test(cover)) return hero;
  return cover || hero;
}
