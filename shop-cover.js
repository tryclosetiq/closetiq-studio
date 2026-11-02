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
    return url.protocol === "https:" && isAmazonHost(url.hostname) !== "";
  } catch { return false; }
}
function shopTilePath(row) {
  const hero = (row && row.collage_public_path) || "";
  const cover = (row && row.cover_public_path) || "";
  if (hero && hero !== cover && !/\/cover\.jpg$/i.test(cover)) return hero;
  return cover || hero;
}
