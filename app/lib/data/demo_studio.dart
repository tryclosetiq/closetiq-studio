import "dart:math";

import "../domain/amazon_tag.dart";
import "../domain/models.dart";
import "../theme/brand.dart";

/// In-memory studio used for the example preview and for the look-sync tests.
/// Mutations follow the SQL rules: outfit_items are the product list, and
/// hidden/order live beside that list.
class DemoStudio {
  DemoStudio(this.snapshot);

  StudioSnapshot snapshot;
  var _seq = 100;

  String _id(String prefix) => "$prefix-${_seq++}";

  factory DemoStudio.heather() {
    final now = DateTime.now();
    DateTime day(int add, int hour, int minute) => DateTime(now.year, now.month, now.day + add, hour, minute);
    const trousers = Garment(
      id: "g-trousers",
      name: "Satin trousers",
      brand: "Amazon",
      category: "bottoms",
      source: "amazon",
      priceText: "\$48",
      affiliateUrl: "https://www.amazon.com/dp/B0SATIN001?tag=heather-20",
      asin: "B0SATIN001",
      swatch: 0xFF5C4638,
    );
    const earrings = Garment(
      id: "g-earrings",
      name: "Gold drop earrings",
      brand: "ShopMy",
      category: "accessory",
      source: "manual",
      priceText: "\$28",
      productUrl: "https://shopmy.us/example/gold-drop-earrings",
      swatch: 0xFFC4A574,
    );
    const knit = Garment(
      id: "g-knit",
      name: "Olive knit",
      brand: "Amazon",
      category: "tops",
      source: "amazon",
      priceText: "\$36",
      affiliateUrl: "https://www.amazon.com/dp/B0OLIVE0001?tag=heather-20",
      asin: "B0OLIVE0001",
      swatch: 0xFF8D7355,
    );
    const blouse = Garment(
      id: "g-blouse",
      name: "Cream blouse",
      brand: "Amazon",
      category: "tops",
      source: "amazon",
      priceText: "\$32",
      affiliateUrl: "https://www.amazon.com/dp/B0CREAM0001?tag=heather-20",
      asin: "B0CREAM0001",
      swatch: 0xFFD9C7A6,
    );
    const loafers = Garment(
      id: "g-loafers",
      name: "Espresso loafers",
      brand: "Amazon",
      category: "shoes",
      source: "amazon",
      priceText: "\$54",
      affiliateUrl: "https://www.amazon.com/dp/B0LOAFER001?tag=heather-20",
      asin: "B0LOAFER001",
      swatch: 0xFFB08A62,
    );
    return DemoStudio(StudioSnapshot(
      example: true,
      settings: const CreatorSettings(
        displayName: "Heather",
        email: "heather@example.com",
        handle: "heather",
        amazonTag: "heather-20",
        disclosure: "As an Amazon Associate I earn from qualifying purchases.",
        hashtags: "#ootd #amazonfinds",
        storefrontTitle: "Shop My Style",
        subtitle: "Outfits, favorite finds and everyday inspiration.",
        onboardingComplete: true,
        creditBalance: 240,
        creditAllowance: 300,
      ),
      clicks7d: 1284,
      clicksPrev7d: 1088,
      garments: const [trousers, earrings, knit, blouse, loafers],
      outfits: const [
        Outfit(id: "o-espresso", name: "Spotted in Espresso", idea: "3 cozy fall looks under \$100, espresso and cream", itemIds: ["g-trousers", "g-earrings", "g-loafers", "g-blouse"]),
        Outfit(id: "o-olive", name: "Olive & On the Go", idea: "Weekend casual", itemIds: ["g-knit", "g-loafers"]),
        Outfit(id: "o-burgundy", name: "Date night, burgundy", idea: "Date night", itemIds: ["g-blouse", "g-earrings", "g-trousers"]),
        Outfit(id: "o-office", name: "Office neutrals", idea: "Office", itemIds: ["g-blouse", "g-trousers"]),
      ],
      meta: const [
        LookMeta(outfitId: "o-espresso", garmentId: "g-trousers", position: 1),
        LookMeta(outfitId: "o-espresso", garmentId: "g-earrings", position: 2),
        LookMeta(outfitId: "o-espresso", garmentId: "g-loafers", position: 3),
        LookMeta(outfitId: "o-espresso", garmentId: "g-blouse", position: 4),
        LookMeta(outfitId: "o-olive", garmentId: "g-knit", position: 1),
        LookMeta(outfitId: "o-olive", garmentId: "g-loafers", position: 2),
        LookMeta(outfitId: "o-burgundy", garmentId: "g-blouse", position: 1),
        LookMeta(outfitId: "o-burgundy", garmentId: "g-earrings", position: 2),
        LookMeta(outfitId: "o-burgundy", garmentId: "g-trousers", position: 3),
        LookMeta(outfitId: "o-office", garmentId: "g-blouse", position: 1),
        LookMeta(outfitId: "o-office", garmentId: "g-trousers", position: 2),
      ],
      pages: const [
        ShopPage(outfitId: "o-espresso", slug: "espresso1", title: "Spotted in Espresso", published: true, featured: true, category: "Date night", swatch: 0xFFB08A62, clicks7d: 212, pieceCount: 6, sortOrder: 0),
        ShopPage(outfitId: "o-olive", slug: "olive00001", title: "Olive & On the Go", published: true, category: "Everyday", swatch: 0xFFC5BEA8, clicks7d: 148, pieceCount: 5, sortOrder: 1),
        ShopPage(outfitId: "o-burgundy", slug: "burg000001", title: "Date night, burgundy", published: false, category: "Date night", swatch: 0xFF5C4638, pieceCount: 4, sortOrder: 2),
        ShopPage(outfitId: "o-office", slug: "office0001", title: "Office neutrals", published: false, category: "Workwear", swatch: 0xFFD9C7A6, pieceCount: 5, sortOrder: 3),
      ],
      collections: const [
        ShopCollection(id: "c-complete", name: "Complete looks", lookCount: 12, detail: "12 looks · synced"),
        ShopCollection(id: "c-fall", name: "Fall under \$100", lookCount: 8, detail: "8 looks", sortOrder: 1),
        ShopCollection(id: "c-gift", name: "Gift guide", hidden: true, lookCount: 0, detail: "Hidden · live Nov 15", sortOrder: 2),
        ShopCollection(id: "c-fav", name: "Favorites", lookCount: 22, detail: "22 finds", sortOrder: 3),
      ],
      posts: [
        ScheduledPost(id: "p-espresso", title: "Espresso Reel", when: day(0, 18, 30), networks: const ["instagram", "storefront"], outfitId: "o-espresso"),
        ScheduledPost(id: "p-date", title: "Date night", when: day(4, 18, 0), networks: const ["instagram"], outfitId: "o-burgundy"),
        ScheduledPost(id: "p-office", title: "Office neutrals", when: day(6, 9, 0), networks: const ["tiktok"], outfitId: "o-office"),
      ],
      attention: const [
        AttentionItem(id: "g-trousers", name: "Satin trousers", detail: "Sold out · In 2 looks", actionLabel: "Swap", swatch: 0xFF5C4638),
        AttentionItem(id: "g-earrings", name: "Gold drop earrings", detail: "Dead link · ShopMy", actionLabel: "Fix", swatch: 0xFFC4A574),
      ],
    ));
  }

  void saveSettings(CreatorSettings settings) {
    snapshot = _copy(settings: settings);
  }

  Garment addGarment(GarmentDraft draft) {
    final tagged = tagAmazon(draft.affiliateUrl ?? "", snapshot.settings.amazonTag);
    final affiliate = (draft.affiliateUrl ?? "").trim().isEmpty ? null : (tagged.url.isEmpty ? null : tagged.url);
    final garment = Garment(
      id: _id("g"),
      name: draft.name.trim(),
      brand: draft.brand.trim(),
      category: draft.category,
      notes: draft.notes.trim(),
      source: draft.source,
      priceText: _blank(draft.priceText),
      productUrl: _blank(draft.productUrl),
      affiliateUrl: affiliate,
      imageUrl: _blank(draft.imageUrl),
      asin: tagged.asin,
      swatch: Brand.swatches[Random(draft.name.hashCode).nextInt(Brand.swatches.length)],
    );
    snapshot = _copy(garments: [...snapshot.garments, garment]);
    return garment;
  }

  void deleteGarment(String id) {
    snapshot = _copy(
      garments: snapshot.garments.where((garment) => garment.id != id).toList(),
      outfits: [
        for (final outfit in snapshot.outfits)
          Outfit(id: outfit.id, name: outfit.name, caption: outfit.caption, idea: outfit.idea, itemIds: outfit.itemIds.where((item) => item != id).toList()),
      ],
      meta: snapshot.meta.where((item) => item.garmentId != id).toList(),
    );
  }

  String createLook({required String name, required String idea, required List<String> itemIds, bool published = false, String caption = ""}) {
    final id = _id("o");
    final outfit = Outfit(id: id, name: name.trim().isEmpty ? "Untitled look" : name.trim(), idea: idea, caption: caption, itemIds: const []);
    final page = ShopPage(
      outfitId: id,
      slug: _id("s").replaceAll("-", "").padRight(10, "0").substring(0, 10),
      title: outfit.name,
      published: published,
      swatch: Brand.swatches[snapshot.pages.length % Brand.swatches.length],
    );
    snapshot = _copy(outfits: [outfit, ...snapshot.outfits], pages: [...snapshot.pages, page]);
    for (final itemId in itemIds) {
      addPiece(id, itemId);
    }
    if (published) setPublished(id, true);
    return id;
  }

  void addPiece(String outfitId, String garmentId) {
    final outfit = snapshot.outfit(outfitId);
    final garment = snapshot.garments.where((item) => item.id == garmentId);
    if (outfit == null || garment.isEmpty) {
      throw StateError("That piece is not in your closet");
    }
    if (outfit.itemIds.contains(garmentId)) return;
    final meta = [
      ...snapshot.meta,
      if (!snapshot.meta.any((item) => item.outfitId == outfitId && item.garmentId == garmentId))
        LookMeta(outfitId: outfitId, garmentId: garmentId, position: outfit.itemIds.length + 1),
    ];
    snapshot = _copy(
      outfits: [
        for (final item in snapshot.outfits)
          if (item.id == outfitId)
            Outfit(id: item.id, name: item.name, caption: item.caption, idea: item.idea, itemIds: [...item.itemIds, garmentId])
          else
            item,
      ],
      meta: meta,
      pages: [
        for (final page in snapshot.pages)
          if (page.outfitId == outfitId) _page(page, imageNeedsRerender: true, pieceCount: page.pieceCount + 1) else page,
      ],
    );
  }

  void removePiece(String outfitId, String garmentId) {
    snapshot = _copy(
      outfits: [
        for (final item in snapshot.outfits)
          if (item.id == outfitId)
            Outfit(id: item.id, name: item.name, caption: item.caption, idea: item.idea, itemIds: item.itemIds.where((id) => id != garmentId).toList())
          else
            item,
      ],
      meta: snapshot.meta.where((item) => !(item.outfitId == outfitId && item.garmentId == garmentId)).toList(),
      pages: [
        for (final page in snapshot.pages)
          if (page.outfitId == outfitId) _page(page, imageNeedsRerender: true) else page,
      ],
    );
  }

  void setHidden(String outfitId, String garmentId, bool hidden) {
    final exists = snapshot.meta.any((item) => item.outfitId == outfitId && item.garmentId == garmentId);
    snapshot = _copy(
      meta: [
        for (final item in snapshot.meta)
          if (item.outfitId == outfitId && item.garmentId == garmentId)
            LookMeta(outfitId: outfitId, garmentId: garmentId, position: item.position, hidden: hidden)
          else
            item,
        if (!exists) LookMeta(outfitId: outfitId, garmentId: garmentId, position: 0, hidden: hidden),
      ],
    );
  }

  void setPublished(String outfitId, bool published) {
    snapshot = _copy(
      pages: [
        for (final page in snapshot.pages)
          if (page.outfitId == outfitId) _page(page, published: published) else page,
      ],
    );
  }

  ShopCollection addCollection(String name) {
    final collection = ShopCollection(id: _id("c"), name: name.trim(), detail: "0 looks", sortOrder: snapshot.collections.length);
    snapshot = _copy(collections: [...snapshot.collections, collection]);
    return collection;
  }

  void setCollectionHidden(String id, bool hidden) {
    snapshot = _copy(
      collections: [
        for (final collection in snapshot.collections)
          if (collection.id == id)
            ShopCollection(
              id: collection.id,
              name: collection.name,
              hidden: hidden,
              sortOrder: collection.sortOrder,
              lookCount: collection.lookCount,
              detail: hidden ? "Hidden" : collection.detail.replaceFirst("Hidden · ", ""),
            )
          else
            collection,
      ],
    );
  }

  ScheduledPost schedule({
    required String title,
    required DateTime when,
    required String caption,
    required List<String> networks,
    String? outfitId,
  }) {
    final post = ScheduledPost(id: _id("p"), title: title, when: when, caption: caption, networks: networks, outfitId: outfitId);
    snapshot = _copy(posts: [...snapshot.posts, post]);
    return post;
  }

  StudioSnapshot _copy({
    CreatorSettings? settings,
    List<Garment>? garments,
    List<Outfit>? outfits,
    List<LookMeta>? meta,
    List<ShopPage>? pages,
    List<ShopCollection>? collections,
    List<ScheduledPost>? posts,
    List<AttentionItem>? attention,
  }) {
    return StudioSnapshot(
      example: snapshot.example,
      settings: settings ?? snapshot.settings,
      garments: garments ?? snapshot.garments,
      outfits: outfits ?? snapshot.outfits,
      meta: meta ?? snapshot.meta,
      pages: pages ?? snapshot.pages,
      collections: collections ?? snapshot.collections,
      posts: posts ?? snapshot.posts,
      attention: attention ?? snapshot.attention,
      clicks7d: snapshot.clicks7d,
      clicksPrev7d: snapshot.clicksPrev7d,
    );
  }

  ShopPage _page(ShopPage page, {bool? published, bool? imageNeedsRerender, int? pieceCount}) {
    return ShopPage(
      outfitId: page.outfitId,
      slug: page.slug,
      title: page.title,
      published: published ?? page.published,
      listed: page.listed,
      featured: page.featured,
      sortOrder: page.sortOrder,
      category: page.category,
      imageNeedsRerender: imageNeedsRerender ?? page.imageNeedsRerender,
      swatch: page.swatch,
      clicks7d: page.clicks7d,
      pieceCount: pieceCount ?? page.pieceCount,
    );
  }

  String? _blank(String? value) {
    final text = value?.trim() ?? "";
    return text.isEmpty ? null : text;
  }
}
