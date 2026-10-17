import "dart:typed_data";

import "package:supabase_flutter/supabase_flutter.dart";

import "../domain/amazon_tag.dart";
import "../domain/handle_rules.dart";
import "../domain/models.dart";
import "../domain/product_meta.dart";
import "../theme/brand.dart";
import "studio_store.dart";

class SupabaseStore implements StudioStore {
  SupabaseStore(this.client);

  final SupabaseClient client;
  StudioSnapshot? _snapshot;

  @override
  StudioSnapshot get snapshot => _snapshot!;

  String get _uid => client.auth.currentUser!.id;

  @override
  Future<void> reload() async {
    final results = await Future.wait([
      client.from("profiles").select().eq("id", _uid).single(),
      client.from("creator_settings").select().eq("user_id", _uid).single(),
      client.from("credit_balances").select().eq("user_id", _uid).maybeSingle(),
      client.from("garments").select().order("created_at", ascending: false),
      client.from("outfits").select().order("updated_at", ascending: false),
      client.from("outfit_items").select().order("position"),
      client.from("shop_pages").select(),
      client.from("shop_look_item_meta").select(),
      client.from("shop_collections").select().order("sort_order"),
      client.from("shop_collection_looks").select(),
      client.from("scheduled_posts").select().order("scheduled_for"),
      client.rpc("my_click_summary"),
    ]);
    final profile = _map(results[0]);
    final settings = _map(results[1]);
    final credits = results[2] == null ? null : _map(results[2]);
    final garments = await _garments(_list(results[3]));
    final outfits = _outfits(_list(results[4]), _list(results[5]));
    final pages = _pages(_list(results[6]), outfits);
    final meta = _meta(_list(results[7]));
    final collectionLinks = _list(results[9]);
    final collections = _collections(_list(results[8]), collectionLinks);
    final posts = _posts(_list(results[10]));
    final summary = results[11] is Map ? _map(results[11]) : const <String, dynamic>{};
    final built = StudioSnapshot(
      settings: CreatorSettings(
        displayName: (profile["display_name"] as String?)?.trim().isNotEmpty == true ? profile["display_name"] as String : "Creator",
        email: client.auth.currentUser?.email ?? "",
        handle: settings["handle"] as String?,
        amazonTag: settings["amazon_tag"] as String?,
        disclosure: (settings["disclosure"] as String?) ?? "As an Amazon Associate I earn from qualifying purchases.",
        hashtags: (settings["hashtags"] as String?) ?? "",
        amazonStorefrontUrl: settings["amazon_storefront_url"] as String?,
        appStoreUrl: settings["app_store_url"] as String?,
        storefrontTitle: (settings["storefront_title"] as String?) ?? "Shop My Style",
        subtitle: settings["storefront_subtitle"] as String?,
        onboardingComplete: profile["onboarding_completed_at"] != null,
        creditBalance: (credits?["balance"] as num?)?.toInt() ?? 0,
        creditAllowance: (credits?["monthly_allowance"] as num?)?.toInt() ?? 0,
      ),
      garments: garments,
      outfits: outfits,
      meta: meta,
      pages: pages,
      collections: collections,
      posts: posts,
      attention: const [],
      clicks7d: (summary["clicks_7d"] as num?)?.toInt() ?? 0,
      clicksPrev7d: (summary["clicks_prev_7d"] as num?)?.toInt() ?? 0,
    );
    _snapshot = StudioSnapshot(
      settings: built.settings,
      garments: built.garments,
      outfits: built.outfits,
      meta: built.meta,
      pages: built.pages,
      collections: built.collections,
      posts: built.posts,
      attention: _attention(built),
      clicks7d: built.clicks7d,
      clicksPrev7d: built.clicksPrev7d,
    );
  }

  @override
  Future<void> saveSettings(CreatorSettings settings) async {
    final handle = settings.handle == null ? null : normalizeHandle(settings.handle!);
    if (handle != null) {
      final error = handleError(handle);
      if (error != null) throw Exception(error);
      final available = await client.rpc("handle_available", params: {"p_handle": handle});
      if (available != true) throw Exception("That handle is already taken.");
    }
    await client.from("profiles").update({"display_name": settings.displayName.trim()}).eq("id", _uid);
    await client.from("creator_settings").update({
      "handle": handle,
      "amazon_tag": _blank(settings.amazonTag),
      "disclosure": settings.disclosure.trim(),
      "hashtags": _blank(settings.hashtags),
      "amazon_storefront_url": _blank(settings.amazonStorefrontUrl),
      "app_store_url": _blank(settings.appStoreUrl),
      "storefront_title": settings.storefrontTitle.trim().isEmpty ? "Shop My Style" : settings.storefrontTitle.trim(),
      "storefront_subtitle": _blank(settings.subtitle),
    }).eq("user_id", _uid);
    if (settings.onboardingComplete && snapshot.settings.onboardingComplete == false) {
      await client.from("profiles").update({"onboarding_completed_at": DateTime.now().toUtc().toIso8601String()}).eq("id", _uid);
    }
    await reload();
  }

  @override
  Future<Garment> addGarment(GarmentDraft draft) async {
    final tagged = tagAmazon(draft.affiliateUrl ?? "", snapshot.settings.amazonTag);
    final affiliate = (draft.affiliateUrl ?? "").trim().isEmpty ? null : tagged.url;
    final row = await client.from("garments").insert({
      "name": draft.name.trim(),
      "brand": draft.brand.trim(),
      "category": draft.category,
      "notes": draft.notes.trim(),
      "source": draft.source,
      "price_text": _blank(draft.priceText),
      "product_url": _blank(draft.productUrl) ?? _blank(draft.affiliateUrl),
      "affiliate_url": affiliate,
      "image_url": _blank(draft.imageUrl),
      "asin": tagged.asin,
    }).select().single();
    final id = row["id"] as String;
    if (draft.photoBytes != null && draft.photoBytes!.isNotEmpty) {
      final path = "$_uid/garments/$id.jpg";
      await client.storage.from("studio").uploadBinary(
            path,
            Uint8List.fromList(draft.photoBytes!),
            fileOptions: const FileOptions(contentType: "image/jpeg", upsert: true),
          );
      await client.from("garments").update({"photo_path": path}).eq("id", id);
    }
    await reload();
    return snapshot.garments.firstWhere((garment) => garment.id == id);
  }

  @override
  Future<void> deleteGarment(String id) async {
    final row = await client.from("garments").select("photo_path, thumb_path, cutout_path, source_path").eq("id", id).maybeSingle();
    await client.from("garments").delete().eq("id", id);
    final paths = [row?["photo_path"], row?["thumb_path"], row?["cutout_path"], row?["source_path"]].whereType<String>().toList();
    if (paths.isNotEmpty) await client.storage.from("studio").remove(paths);
    await reload();
  }

  @override
  Future<String> createLook({
    required String name,
    required String idea,
    required List<String> itemIds,
    required String caption,
    required bool published,
  }) async {
    final row = await client.from("outfits").insert({
      "name": name.trim().isEmpty ? "Untitled look" : name.trim(),
      "idea": idea,
      "caption": caption,
    }).select("id").single();
    final id = row["id"] as String;
    for (final itemId in itemIds) {
      await client.from("outfit_items").insert({"outfit_id": id, "garment_id": itemId});
    }
    if (published) {
      await client.from("shop_pages").update({
        "published": true,
        "published_at": DateTime.now().toUtc().toIso8601String(),
        "title": name.trim().isEmpty ? "Untitled look" : name.trim(),
      }).eq("outfit_id", id);
    }
    await reload();
    return id;
  }

  @override
  Future<void> addPiece(String outfitId, String garmentId) async {
    await client.from("outfit_items").insert({"outfit_id": outfitId, "garment_id": garmentId});
    await reload();
  }

  @override
  Future<void> removePiece(String outfitId, String garmentId) async {
    await client.from("outfit_items").delete().eq("outfit_id", outfitId).eq("garment_id", garmentId);
    await reload();
  }

  @override
  Future<void> setHidden(String outfitId, String garmentId, bool hidden) async {
    await client.from("shop_look_item_meta").update({"hidden": hidden}).eq("outfit_id", outfitId).eq("garment_id", garmentId);
    await reload();
  }

  @override
  Future<void> setPublished(String outfitId, bool published) async {
    await client.from("shop_pages").update({
      "published": published,
      "published_at": published ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq("outfit_id", outfitId);
    await reload();
  }

  @override
  Future<void> addCollection(String name) async {
    await client.from("shop_collections").insert({"name": name.trim(), "sort_order": snapshot.collections.length});
    await reload();
  }

  @override
  Future<void> setCollectionHidden(String id, bool hidden) async {
    await client.from("shop_collections").update({"hidden": hidden}).eq("id", id);
    await reload();
  }

  @override
  Future<ScheduledPost> schedule({
    required String title,
    required DateTime when,
    required String caption,
    required List<String> networks,
    String? outfitId,
  }) async {
    final row = await client.from("scheduled_posts").insert({
      "title": title,
      "caption": caption,
      "networks": networks,
      "scheduled_for": when.toUtc().toIso8601String(),
      "outfit_id": outfitId,
      "status": "reminder",
    }).select("id").single();
    await client.rpc("refresh_post_links", params: {"p_post": row["id"]});
    await reload();
    return snapshot.posts.firstWhere((post) => post.id == row["id"]);
  }

  Future<ImportResult> importUrl(String url) async {
    final importer = ProductImporter(viaFunction: (raw) async {
      final response = await client.functions.invoke("import-product", body: {"url": raw});
      final data = response.data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {"ok": false, "message": "Couldn't read that page."};
    });
    return importer.import(url);
  }

  Future<List<Garment>> _garments(List<Map<String, dynamic>> rows) async {
    final garments = <Garment>[];
    for (final row in rows) {
      String? photoUrl;
      final path = row["photo_path"] as String?;
      if (path != null && path.isNotEmpty) {
        try {
          photoUrl = await client.storage.from("studio").createSignedUrl(path, 3600);
        } catch (_) {}
      }
      garments.add(Garment(
        id: row["id"] as String,
        name: (row["name"] as String?) ?? "",
        brand: (row["brand"] as String?) ?? "",
        category: (row["category"] as String?) ?? "other",
        notes: (row["notes"] as String?) ?? "",
        source: (row["source"] as String?) ?? "manual",
        priceText: row["price_text"] as String?,
        productUrl: row["product_url"] as String?,
        affiliateUrl: row["affiliate_url"] as String?,
        imageUrl: row["image_url"] as String?,
        photoUrl: photoUrl,
        asin: row["asin"] as String?,
        swatch: _swatch(row["id"] as String),
      ));
    }
    return garments;
  }

  List<Outfit> _outfits(List<Map<String, dynamic>> outfits, List<Map<String, dynamic>> items) {
    return [
      for (final row in outfits)
        Outfit(
          id: row["id"] as String,
          name: (row["name"] as String?) ?? "Untitled look",
          caption: (row["caption"] as String?) ?? "",
          idea: (row["idea"] as String?) ?? "",
          itemIds: [
            for (final item in items)
              if (item["outfit_id"] == row["id"]) item["garment_id"] as String,
          ],
        ),
    ];
  }

  List<LookMeta> _meta(List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows)
        LookMeta(
          outfitId: row["outfit_id"] as String,
          garmentId: row["garment_id"] as String,
          position: (row["position"] as num?)?.toInt() ?? 0,
          hidden: row["hidden"] == true,
        ),
    ];
  }

  List<ShopPage> _pages(List<Map<String, dynamic>> rows, List<Outfit> outfits) {
    return [
      for (final row in rows)
        ShopPage(
          outfitId: row["outfit_id"] as String,
          slug: row["slug"] as String,
          title: (row["title"] as String?) ?? "Look",
          published: row["published"] == true,
          listed: row["listed"] != false,
          featured: row["featured"] == true,
          sortOrder: (row["sort_order"] as num?)?.toInt() ?? 0,
          category: row["category"] as String?,
          imageNeedsRerender: row["image_needs_rerender"] == true,
          swatch: _swatch(row["outfit_id"] as String),
          pieceCount: outfits.where((outfit) => outfit.id == row["outfit_id"]).fold(0, (_, outfit) => outfit.itemIds.length),
        ),
    ];
  }

  List<ShopCollection> _collections(List<Map<String, dynamic>> rows, List<Map<String, dynamic>> links) {
    return [
      for (final row in rows)
        ShopCollection(
          id: row["id"] as String,
          name: (row["name"] as String?) ?? "Collection",
          hidden: row["hidden"] == true,
          sortOrder: (row["sort_order"] as num?)?.toInt() ?? 0,
          lookCount: links.where((link) => link["collection_id"] == row["id"]).length,
          detail: "${links.where((link) => link["collection_id"] == row["id"]).length} looks${row["hidden"] == true ? " · hidden" : ""}",
        ),
    ];
  }

  List<ScheduledPost> _posts(List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows)
        ScheduledPost(
          id: row["id"] as String,
          title: (row["title"] as String?) ?? "Post",
          when: DateTime.tryParse((row["scheduled_for"] as String?) ?? "")?.toLocal() ?? DateTime.now(),
          caption: (row["caption"] as String?) ?? "",
          networks: ((row["networks"] as List?) ?? const []).map((item) => item.toString()).toList(),
          outfitId: row["outfit_id"] as String?,
          status: (row["status"] as String?) ?? "reminder",
        ),
    ];
  }

  List<AttentionItem> _attention(StudioSnapshot snapshot) {
    final items = <AttentionItem>[];
    for (final page in snapshot.pages.where((page) => page.published)) {
      for (final piece in snapshot.pieces(page.outfitId, includeHidden: false)) {
        if (!piece.garment.notMonetized || items.any((item) => item.id == piece.garment.id)) continue;
        items.add(AttentionItem(
          id: piece.garment.id,
          name: piece.garment.name,
          detail: "No affiliate link yet",
          actionLabel: "Fix",
          swatch: piece.garment.swatch,
        ));
      }
    }
    return items;
  }
}

List<Map<String, dynamic>> _list(Object? data) {
  return (data as List).map((row) => Map<String, dynamic>.from(row as Map)).toList();
}

Map<String, dynamic> _map(Object? data) => Map<String, dynamic>.from(data as Map);

String? _blank(String? value) {
  final text = value?.trim() ?? "";
  return text.isEmpty ? null : text;
}

int _swatch(String id) {
  final index = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return Brand.swatches[index % Brand.swatches.length];
}
