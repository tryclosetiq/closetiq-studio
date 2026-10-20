class Garment {
  const Garment({
    required this.id,
    required this.name,
    this.brand = "",
    this.category = "other",
    this.notes = "",
    this.source = "manual",
    this.priceText,
    this.productUrl,
    this.affiliateUrl,
    this.imageUrl,
    this.photoUrl,
    this.asin,
    this.swatch = 0xFFB08A62,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String notes;
  final String source;
  final String? priceText;
  final String? productUrl;
  final String? affiliateUrl;
  final String? imageUrl;
  final String? photoUrl;
  final String? asin;
  final int swatch;

  bool get notMonetized => affiliateUrl == null || affiliateUrl!.trim().isEmpty;

  String get displayImage => photoUrl ?? imageUrl ?? "";
}

class GarmentDraft {
  const GarmentDraft({
    required this.name,
    this.brand = "",
    this.category = "other",
    this.notes = "",
    this.source = "manual",
    this.priceText,
    this.productUrl,
    this.affiliateUrl,
    this.imageUrl,
    this.photoBytes,
    this.asin,
  });

  final String name;
  final String brand;
  final String category;
  final String notes;
  final String source;
  final String? priceText;
  final String? productUrl;
  final String? affiliateUrl;
  final String? imageUrl;
  final List<int>? photoBytes;
  final String? asin;
}

class Outfit {
  const Outfit({
    required this.id,
    required this.name,
    this.caption = "",
    this.idea = "",
    this.itemIds = const [],
  });

  final String id;
  final String name;
  final String caption;
  final String idea;
  final List<String> itemIds;
}

class LookMeta {
  const LookMeta({
    required this.outfitId,
    required this.garmentId,
    required this.position,
    this.hidden = false,
  });

  final String outfitId;
  final String garmentId;
  final int position;
  final bool hidden;
}

class LookPiece {
  const LookPiece({required this.garment, required this.hidden, required this.position});

  final Garment garment;
  final bool hidden;
  final int position;
}

class ShopPage {
  const ShopPage({
    required this.outfitId,
    required this.slug,
    required this.title,
    this.published = false,
    this.listed = true,
    this.featured = false,
    this.sortOrder = 0,
    this.category,
    this.imageNeedsRerender = false,
    this.swatch = 0xFFB08A62,
    this.clicks7d = 0,
    this.pieceCount = 0,
  });

  final String outfitId;
  final String slug;
  final String title;
  final bool published;
  final bool listed;
  final bool featured;
  final int sortOrder;
  final String? category;
  final bool imageNeedsRerender;
  final int swatch;
  final int clicks7d;
  final int pieceCount;

  String get status {
    if (!published) return "Draft";
    return "Live";
  }
}

class ShopCollection {
  const ShopCollection({
    required this.id,
    required this.name,
    this.hidden = false,
    this.sortOrder = 0,
    this.lookCount = 0,
    this.detail = "",
  });

  final String id;
  final String name;
  final bool hidden;
  final int sortOrder;
  final int lookCount;
  final String detail;
}

class ScheduledPost {
  const ScheduledPost({
    required this.id,
    required this.title,
    required this.when,
    this.caption = "",
    this.networks = const [],
    this.outfitId,
    this.status = "reminder",
  });

  final String id;
  final String title;
  final DateTime when;
  final String caption;
  final List<String> networks;
  final String? outfitId;
  final String status;
}

class AttentionItem {
  const AttentionItem({
    required this.id,
    required this.name,
    required this.detail,
    required this.actionLabel,
    this.swatch = 0xFFC5BEA8,
  });

  final String id;
  final String name;
  final String detail;
  final String actionLabel;
  final int swatch;
}

class CreatorSettings {
  const CreatorSettings({
    required this.displayName,
    required this.email,
    this.handle,
    this.amazonTag,
    this.disclosure = "As an Amazon Associate I earn from qualifying purchases.",
    this.hashtags = "",
    this.amazonStorefrontUrl,
    this.appStoreUrl,
    this.storefrontTitle = "Shop My Style",
    this.subtitle = "Outfits, favorite finds and everyday inspiration.",
    this.onboardingComplete = false,
    this.creditBalance = 0,
    this.creditAllowance = 0,
    this.usedToday = 0,
    this.dailyCap = 20,
  });

  final String displayName;
  final String email;
  final String? handle;
  final String? amazonTag;
  final String disclosure;
  final String hashtags;
  final String? amazonStorefrontUrl;
  final String? appStoreUrl;
  final String storefrontTitle;
  final String? subtitle;
  final bool onboardingComplete;
  final int creditBalance;
  final int creditAllowance;
  final int usedToday;
  final int dailyCap;

  String get usageLabel => "$usedToday/$dailyCap today · $creditBalance left";

  CreatorSettings copyWith({
    String? displayName,
    String? email,
    String? handle,
    String? amazonTag,
    String? disclosure,
    String? hashtags,
    String? amazonStorefrontUrl,
    String? appStoreUrl,
    String? storefrontTitle,
    String? subtitle,
    bool? onboardingComplete,
    int? creditBalance,
    int? creditAllowance,
    int? usedToday,
    int? dailyCap,
    bool clearHandle = false,
    bool clearTag = false,
  }) {
    return CreatorSettings(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      handle: clearHandle ? null : (handle ?? this.handle),
      amazonTag: clearTag ? null : (amazonTag ?? this.amazonTag),
      disclosure: disclosure ?? this.disclosure,
      hashtags: hashtags ?? this.hashtags,
      amazonStorefrontUrl: amazonStorefrontUrl ?? this.amazonStorefrontUrl,
      appStoreUrl: appStoreUrl ?? this.appStoreUrl,
      storefrontTitle: storefrontTitle ?? this.storefrontTitle,
      subtitle: subtitle ?? this.subtitle,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      creditBalance: creditBalance ?? this.creditBalance,
      creditAllowance: creditAllowance ?? this.creditAllowance,
      usedToday: usedToday ?? this.usedToday,
      dailyCap: dailyCap ?? this.dailyCap,
    );
  }
}

class StudioSnapshot {
  const StudioSnapshot({
    required this.settings,
    required this.garments,
    required this.outfits,
    required this.meta,
    required this.pages,
    required this.collections,
    required this.posts,
    required this.attention,
    required this.clicks7d,
    required this.clicksPrev7d,
    this.example = false,
  });

  final CreatorSettings settings;
  final List<Garment> garments;
  final List<Outfit> outfits;
  final List<LookMeta> meta;
  final List<ShopPage> pages;
  final List<ShopCollection> collections;
  final List<ScheduledPost> posts;
  final List<AttentionItem> attention;
  final int clicks7d;
  final int clicksPrev7d;
  final bool example;

  int? get clickDeltaPercent {
    if (clicksPrev7d <= 0) return clicks7d > 0 ? 100 : null;
    return (((clicks7d - clicksPrev7d) / clicksPrev7d) * 100).round();
  }

  ScheduledPost? get upNext {
    final now = DateTime.now();
    final upcoming = posts.where((post) => post.status != "cancelled" && !post.when.isBefore(now.subtract(const Duration(hours: 12)))).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  ShopPage? pageFor(String outfitId) {
    for (final page in pages) {
      if (page.outfitId == outfitId) return page;
    }
    return null;
  }

  Outfit? outfit(String id) {
    for (final item in outfits) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<LookPiece> pieces(String outfitId, {bool includeHidden = true}) {
    final found = outfit(outfitId);
    if (found == null) return const [];
    final byId = {for (final garment in garments) garment.id: garment};
    final byMeta = {for (final item in meta) "${item.outfitId}|${item.garmentId}": item};
    final pieces = <LookPiece>[];
    for (var i = 0; i < found.itemIds.length; i++) {
      final garment = byId[found.itemIds[i]];
      if (garment == null) continue;
      final itemMeta = byMeta["$outfitId|${garment.id}"];
      final hidden = itemMeta?.hidden ?? false;
      if (!includeHidden && hidden) continue;
      pieces.add(LookPiece(garment: garment, hidden: hidden, position: itemMeta?.position ?? i + 1));
    }
    pieces.sort((a, b) => a.position.compareTo(b.position));
    return pieces;
  }
}

String draftCaption({required String idea, required List<Garment> pieces, required String disclosure}) {
  final names = pieces.take(4).map((garment) => garment.name).where((name) => name.isNotEmpty).join(", ");
  final count = pieces.length;
  final lines = <String>[
    if (idea.trim().isNotEmpty) idea.trim(),
    if (count > 0) "$count ${count == 1 ? "piece" : "pieces"}${names.isEmpty ? "" : ": $names"}. Shop via the link in my bio.",
    disclosure.trim().isEmpty ? "As an Amazon Associate I earn from qualifying purchases." : disclosure.trim(),
    "#ad",
  ];
  return lines.join("\n\n");
}

String formatDay(DateTime date) {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return "${months[date.month - 1]} ${date.day}";
}

String formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, "0");
  final suffix = date.hour >= 12 ? "PM" : "AM";
  return "$hour:$minute $suffix";
}

String greetingFor(DateTime date) {
  if (date.hour < 12) return "Good morning";
  if (date.hour < 17) return "Good afternoon";
  return "Good evening";
}
