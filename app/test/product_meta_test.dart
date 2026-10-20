import "package:closetiq_studio/domain/product_meta.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const page = "https://shop.example.com/products/satin-trousers";

  test("reads Open Graph title, image and price", () {
    const html = """
      <meta property="og:title" content="Satin trousers &amp; cream tee">
      <meta property="og:image" content="/photos/trousers.jpg">
      <meta property="product:price:amount" content="48.00">
      <meta property="product:price:currency" content="USD">
    """;
    final meta = extractProductMeta(html, page);
    expect(meta.name, "Satin trousers & cream tee");
    expect(meta.imageUrl, "https://shop.example.com/photos/trousers.jpg");
    expect(meta.priceText, "\$48.00");
  });

  test("prefers JSON-LD product fields", () {
    const html = """
      <title>Ignored</title>
      <meta property="og:title" content="OG name">
      <script type="application/ld+json">
        {"@graph":[{"@type":"Product","name":"Gold drop earrings","image":["https://cdn.example.com/ear.jpg"],
          "offers":{"price":"28","priceCurrency":"USD"}}]}
      </script>
    """;
    final meta = extractProductMeta(html, page);
    expect(meta.name, "Gold drop earrings");
    expect(meta.imageUrl, "https://cdn.example.com/ear.jpg");
    expect(meta.priceText, "\$28");
  });

  test("falls back to the manual form when the page has nothing or the link is blocked", () async {
    final empty = await const ProductImporter(fetchHtml: _empty).import("https://shop.example.com/x");
    expect(empty.ok, isFalse);
    expect(empty.message, contains("Add the details yourself"));

    final blocked = await const ProductImporter().import("http://shop.example.com/x");
    expect(blocked.ok, isFalse);
    expect(blocked.message, contains("https"));

    final unconfigured = await const ProductImporter().import("https://shop.example.com/x");
    expect(unconfigured.ok, isFalse);
    expect(unconfigured.message, contains("import-product"));
  });

  test("uses the edge function response when it is present", () async {
    final result = await ProductImporter(viaFunction: (url) async {
      return {"ok": true, "source_url": url, "name": "Wool coat", "price_text": "\$120", "image_url": "https://cdn.example.com/coat.jpg"};
    }).import("https://shop.example.com/coat");
    expect(result.ok, isTrue);
    expect(result.name, "Wool coat");
    expect(result.priceText, "\$120");
  });
}

Future<String> _empty(String url) async => "<html><title> </title></html>";
