import "dart:convert";

/// Public product-page metadata. The same rules live in
/// `supabase/functions/_shared/product_meta.js`, which is what the edge
/// function runs. This copy lets the app and its tests agree on a fill.
class ProductMeta {
  const ProductMeta({this.name, this.imageUrl, this.priceText, this.currency});

  final String? name;
  final String? imageUrl;
  final String? priceText;
  final String? currency;

  bool get hasAny => name != null || imageUrl != null || priceText != null;
}

class ImportResult {
  const ImportResult({
    required this.ok,
    required this.sourceUrl,
    this.name,
    this.imageUrl,
    this.priceText,
    this.message = "",
  });

  final bool ok;
  final String sourceUrl;
  final String? name;
  final String? imageUrl;
  final String? priceText;
  final String message;

  factory ImportResult.fallback(String url, String message) {
    return ImportResult(ok: false, sourceUrl: url, message: message);
  }

  factory ImportResult.fromFunction(Map<String, dynamic> json, String url) {
    if (json["ok"] == true) {
      return ImportResult(
        ok: true,
        sourceUrl: (json["source_url"] as String?) ?? url,
        name: json["name"] as String?,
        imageUrl: json["image_url"] as String?,
        priceText: json["price_text"] as String?,
      );
    }
    return ImportResult.fallback(
      url,
      (json["message"] as String?) ?? "Couldn't read that page. Add the details yourself.",
    );
  }
}

/// [viaFunction] calls the import-product edge function.
/// [fetchHtml] is for tests, and for a caller that already has the HTML.
class ProductImporter {
  const ProductImporter({this.viaFunction, this.fetchHtml});

  final Future<Map<String, dynamic>> Function(String url)? viaFunction;
  final Future<String> Function(String url)? fetchHtml;

  Future<ImportResult> import(String url) async {
    final raw = url.trim();
    try {
      assertPublicHttpsUrl(raw);
    } catch (error) {
      return ImportResult.fallback(raw, "$error Add the photo, name and price yourself.");
    }
    if (viaFunction != null) {
      try {
        return ImportResult.fromFunction(await viaFunction!(raw), raw);
      } catch (_) {
        return ImportResult.fallback(raw, "Couldn't read that page. Add the photo, name and price yourself.");
      }
    }
    if (fetchHtml != null) {
      try {
        final meta = extractProductMeta(await fetchHtml!(raw), raw);
        if (!meta.hasAny) {
          return ImportResult.fallback(raw, "That page didn't share a name, photo or price. Add the details yourself.");
        }
        return ImportResult(ok: true, sourceUrl: raw, name: meta.name, imageUrl: meta.imageUrl, priceText: meta.priceText);
      } catch (_) {
        return ImportResult.fallback(raw, "Couldn't read that page. Add the photo, name and price yourself.");
      }
    }
    return ImportResult.fallback(
      raw,
      "Product import needs the import-product function. Add the photo, name and price yourself.",
    );
  }
}

void assertPublicHttpsUrl(String raw) {
  final url = Uri.tryParse(raw.trim());
  if (url == null || !url.hasScheme || url.host.isEmpty) {
    throw Exception("That doesn't look like a valid URL.");
  }
  if (url.userInfo.isNotEmpty) {
    throw Exception("Links with a username or password can't be imported.");
  }
  if (url.scheme != "https") throw Exception("Only https links can be imported.");
  final host = url.host.toLowerCase().replaceAll(RegExp(r"\.+$"), "");
  if (host == "localhost" ||
      host == "metadata.google.internal" ||
      host.endsWith(".local") ||
      host.endsWith(".internal") ||
      host.endsWith(".localhost")) {
    throw Exception("That link can't be imported.");
  }
  if (_isIp(host) && !_isPublicIp(host)) throw Exception("That link can't be imported.");
}

ProductMeta extractProductMeta(String html, String pageUrl) {
  final base = Uri.tryParse(pageUrl);
  final ld = _readJsonLd(html);
  final ogTitle = _meta(html, "og:title").isNotEmpty ? _meta(html, "og:title") : _meta(html, "twitter:title");
  final picked = ld.name.isNotEmpty ? ld.name : (ogTitle.isNotEmpty ? ogTitle : _title(html));
  final name = _clean(picked);
  final imageRaw = ld.image.isNotEmpty
      ? ld.image
      : (_meta(html, "og:image").isNotEmpty ? _meta(html, "og:image") : _meta(html, "twitter:image"));
  final amount = ld.price.isNotEmpty
      ? ld.price
      : (_meta(html, "product:price:amount").isNotEmpty ? _meta(html, "product:price:amount") : _meta(html, "og:price:amount"));
  final currencyRaw = ld.currency.isNotEmpty
      ? ld.currency
      : (_meta(html, "product:price:currency").isNotEmpty ? _meta(html, "product:price:currency") : _meta(html, "og:price:currency"));
  final currency = currencyRaw.toUpperCase();
  return ProductMeta(
    name: name.isEmpty ? null : name,
    imageUrl: _resolve(imageRaw, base),
    priceText: _formatPrice(amount, currency),
    currency: currency.isEmpty ? null : currency,
  );
}

class _Ld {
  String name = "";
  String image = "";
  String price = "";
  String currency = "";
}

String _clean(String value) {
  final text = _decode(value).replaceAll(RegExp(r"\s+"), " ").trim();
  return text.length > 200 ? text.substring(0, 200) : text;
}

String _decode(String value) {
  return value
      .replaceAllMapped(RegExp(r"&#x([0-9a-fA-F]+);"), (m) => _char(int.tryParse(m.group(1)!, radix: 16)))
      .replaceAllMapped(RegExp(r"&#(\d+);"), (m) => _char(int.tryParse(m.group(1)!)))
      .replaceAll("&amp;", "&")
      .replaceAll("&quot;", '"')
      .replaceAll("&#39;", "'")
      .replaceAll("&apos;", "'")
      .replaceAll("&lt;", "<")
      .replaceAll("&gt;", ">");
}

String _char(int? code) {
  if (code == null || code < 32 || code > 0x10ffff) return "";
  return String.fromCharCode(code);
}

String _meta(String html, String key) {
  for (final tag in RegExp(r"<meta\b[^>]*>", caseSensitive: false).allMatches(html)) {
    final text = tag.group(0)!;
    final property = (_attr(text, "property").isNotEmpty ? _attr(text, "property") : _attr(text, "name")).toLowerCase();
    if (property != key.toLowerCase()) continue;
    final content = _attr(text, "content");
    if (content.isNotEmpty) return _decode(content).trim();
  }
  return "";
}

String _attr(String tag, String name) {
  final match = RegExp("\\b$name\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))", caseSensitive: false).firstMatch(tag);
  return match?.group(1) ?? match?.group(2) ?? match?.group(3) ?? "";
}

String _title(String html) {
  return RegExp(r"<title[^>]*>([\s\S]*?)</title>", caseSensitive: false).firstMatch(html)?.group(1) ?? "";
}

_Ld _readJsonLd(String html) {
  final out = _Ld();
  final blocks = RegExp(
    "<script\\b[^>]*type\\s*=\\s*[\"']application/ld\\+json[\"'][^>]*>[\\s\\S]*?</script>",
    caseSensitive: false,
  ).allMatches(html);
  for (final block in blocks) {
    final body = block.group(0)!.replaceFirst(RegExp(r"^[\s\S]*?>"), "").replaceFirst(RegExp(r"</script>\s*$", caseSensitive: false), "");
    try {
      _absorb(jsonDecode(body), out);
    } catch (_) {}
  }
  return out;
}

void _absorb(Object? node, _Ld out) {
  if (node is List) {
    for (final item in node) {
      _absorb(item, out);
    }
    return;
  }
  if (node is! Map) return;
  if (node.containsKey("@graph")) _absorb(node["@graph"], out);
  final type = node["@type"];
  final types = (type is List ? type : [type]).whereType<Object>().map((item) => item.toString().toLowerCase());
  if (types.contains("product")) {
    if (out.name.isEmpty && node["name"] != null) out.name = node["name"].toString();
    if (out.image.isEmpty) out.image = _imageOf(node["image"]);
    final offers = node["offers"];
    final offer = offers is List && offers.isNotEmpty ? offers.first : offers;
    if (offer is Map) {
      if (out.price.isEmpty) out.price = (offer["price"] ?? offer["lowPrice"] ?? "").toString();
      if (out.currency.isEmpty && offer["priceCurrency"] != null) out.currency = offer["priceCurrency"].toString();
    }
  }
  for (final value in node.values) {
    if (value is Map || value is List) _absorb(value, out);
  }
}

String _imageOf(Object? image) {
  if (image is String) return image;
  if (image is List && image.isNotEmpty) return _imageOf(image.first);
  if (image is Map && image["url"] != null) return image["url"].toString();
  return "";
}

String? _resolve(String value, Uri? base) {
  final raw = _clean(value);
  if (raw.isEmpty || base == null) return null;
  final resolved = base.resolveUri(Uri.parse(raw));
  if (resolved.scheme != "https") return null;
  return resolved.toString();
}

String? _formatPrice(String amount, String currency) {
  final raw = amount.trim().replaceAll(",", "");
  if (raw.isEmpty) return null;
  final value = double.tryParse(raw);
  if (value == null || value < 0 || value > 1000000) return null;
  // Keep ".00" when the page published a decimal, so "$48.00" stays distinct from a whole-dollar "$48".
  final fixed = raw.contains(".") || value != value.roundToDouble() ? value.toStringAsFixed(2) : value.toStringAsFixed(0);
  if (currency.isEmpty || currency == "USD") return "\$$fixed";
  return "$currency $fixed";
}

bool _isIp(String host) => RegExp(r"^\d{1,3}(\.\d{1,3}){3}$").hasMatch(host) || host.contains(":");

bool _isPublicIp(String host) {
  if (host.contains(":")) {
    final h = host.toLowerCase();
    if (h == "::1" || h == "::" || h.startsWith("fe80:") || h.startsWith("fc") || h.startsWith("fd")) return false;
    return true;
  }
  final parts = host.split(".").map(int.parse).toList();
  if (parts.any((n) => n > 255)) return false;
  final a = parts[0];
  final b = parts[1];
  if (a == 10 || a == 127 || a == 0) return false;
  if (a == 169 && b == 254) return false;
  if (a == 172 && b >= 16 && b <= 31) return false;
  if (a == 192 && b == 168) return false;
  if (a == 100 && b >= 64 && b <= 127) return false;
  return true;
}
