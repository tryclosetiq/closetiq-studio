/// Amazon Associates tagging, ported from the current Studio page so saved
/// links keep the same shape: a clean /dp/ASIN url and the creator's own tag.
class AmazonTagResult {
  const AmazonTagResult(this.url, this.asin, this.note);

  final String url;
  final String? asin;
  final String note;
}

AmazonTagResult tagAmazon(String input, String? tag) {
  final raw = input.trim();
  final tracking = (tag ?? "").trim();
  if (raw.isEmpty) return const AmazonTagResult("", null, "");
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return AmazonTagResult(raw, null, "That doesn't look like a valid URL.");
  }
  final host = uri.host.toLowerCase();
  if (RegExp(r"(^|\.)(amzn\.(to|com|eu|asia|in)|a\.co)$").hasMatch(host)) {
    return AmazonTagResult(raw, null, "Short link kept — it already carries its tag.");
  }
  if (!RegExp(r"(^|\.)amazon\.[a-z.]+$").hasMatch(host)) {
    return AmazonTagResult(raw, null, "Not an Amazon link — saved as is.");
  }
  final match = RegExp(
        r"/(?:dp|gp/product|gp/aw/d|product)/([A-Z0-9]{10})(?:[/?#]|$)",
        caseSensitive: false,
      ).firstMatch(uri.path) ??
      RegExp(r"/([B][0-9A-Z]{9})(?:[/?#]|$)", caseSensitive: false).firstMatch(uri.path);
  final asin = match?.group(1)?.toUpperCase();
  final existing = uri.queryParameters["tag"];
  if (existing != null && existing.isNotEmpty && tracking.isNotEmpty && existing != tracking) {
    return AmazonTagResult(
      raw,
      asin,
      'Kept the link\'s existing tag "$existing" (Amazon allows one tag per link).',
    );
  }
  if (asin == null) {
    if (tracking.isEmpty) return AmazonTagResult(raw, null, "");
    final next = uri.replace(queryParameters: {...uri.queryParameters, "tag": tracking});
    return AmazonTagResult(next.toString(), null, "Tagged, but no ASIN found in this URL.");
  }
  final clean = Uri.https(host, "/dp/$asin", tracking.isEmpty ? null : {"tag": tracking});
  final note = tracking.isEmpty ? "ASIN $asin · no tracking ID set yet" : "Clean tagged link · ASIN $asin";
  return AmazonTagResult(clean.toString(), asin, note);
}
