// Picture shown on a public storefront tile. shop.html and the Studio editor both use this.
// The look page itself always uses collage_public_path.
// A custom shop image (custom.jpg), or any hero that is not the cover file, wins over the
// auto product grid. An AI-photo cover (cover.jpg) stays ahead of that grid.
// Empty cover_public_path still shows the hero, so a look is not left as a blank tile.
function shopTilePath(row) {
  const hero = (row && row.collage_public_path) || "";
  const cover = (row && row.cover_public_path) || "";
  if (hero && hero !== cover && !/\/cover\.jpg$/i.test(cover)) return hero;
  return cover || hero;
}
