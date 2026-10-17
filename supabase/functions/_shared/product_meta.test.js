import test from "node:test";
import assert from "node:assert/strict";
import { assertPublicHttpsUrl, extractProductMeta } from "./product_meta.js";

const page = "https://shop.example.com/products/satin-trousers";

test("reads Open Graph title, image and price", () => {
  const html = `
    <html><head>
      <meta property="og:title" content="Satin trousers &amp; cream tee">
      <meta property="og:image" content="/photos/trousers.jpg">
      <meta property="product:price:amount" content="48.00">
      <meta property="product:price:currency" content="USD">
    </head></html>`;
  const meta = extractProductMeta(html, page);
  assert.equal(meta.name, "Satin trousers & cream tee");
  assert.equal(meta.imageUrl, "https://shop.example.com/photos/trousers.jpg");
  assert.equal(meta.priceText, "$48.00");
  assert.equal(meta.hasAny, true);
});

test("prefers JSON-LD product fields, including @graph", () => {
  const html = `
    <html><head>
      <title>Ignored page title</title>
      <meta property="og:title" content="OG name">
      <meta property="og:image" content="https://cdn.example.com/og.jpg">
      <script type="application/ld+json">
        {"@graph":[{"@type":"Product","name":"Gold drop earrings","image":["https://cdn.example.com/ear.jpg"],
          "offers":{"@type":"Offer","price":"28","priceCurrency":"USD"}}]}
      </script>
    </head></html>`;
  const meta = extractProductMeta(html, page);
  assert.equal(meta.name, "Gold drop earrings");
  assert.equal(meta.imageUrl, "https://cdn.example.com/ear.jpg");
  assert.equal(meta.priceText, "$28");
});

test("falls back to the title tag when product metadata is missing", () => {
  const meta = extractProductMeta("<html><head><title>  Wool coat  </title></head><body></body></html>", page);
  assert.equal(meta.name, "Wool coat");
  assert.equal(meta.imageUrl, null);
  assert.equal(meta.priceText, null);
});

test("ignores broken JSON-LD and non-https images", () => {
  const html = `
    <script type="application/ld+json">{not json</script>
    <meta property="og:title" content="Linen shirt">
    <meta property="og:image" content="http://insecure.example.com/a.jpg">`;
  const meta = extractProductMeta(html, page);
  assert.equal(meta.name, "Linen shirt");
  assert.equal(meta.imageUrl, null);
});

test("rejects links that are not public https", () => {
  assert.equal(assertPublicHttpsUrl("https://www.amazon.com/dp/B00TEST123").hostname, "www.amazon.com");
  for (const bad of [
    "http://shop.example.com/a",
    "https://localhost/a",
    "https://127.0.0.1/a",
    "https://10.0.0.8/a",
    "https://192.168.1.4/a",
    "https://169.254.169.254/latest",
    "https://user:pass@shop.example.com/a",
    "not a url",
    "https://printer.local/a",
  ]) {
    assert.throws(() => assertPublicHttpsUrl(bad), bad);
  }
});
