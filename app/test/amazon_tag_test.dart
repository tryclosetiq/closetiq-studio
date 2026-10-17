import "package:closetiq_studio/domain/amazon_tag.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("builds a clean tagged Amazon link from a product url", () {
    final result = tagAmazon("https://www.amazon.com/Some-Name/dp/B0SATIN001/ref=sr", "heather-20");
    expect(result.asin, "B0SATIN001");
    expect(result.url, "https://www.amazon.com/dp/B0SATIN001?tag=heather-20");
    expect(result.note, contains("ASIN"));
  });

  test("keeps a non-Amazon link and a short link as entered", () {
    expect(tagAmazon("https://shopmy.us/example/earrings", "heather-20").note, contains("Not an Amazon"));
    expect(tagAmazon("https://amzn.to/abc", "heather-20").url, "https://amzn.to/abc");
  });

  test("does not replace a different tag already on the link", () {
    final result = tagAmazon("https://www.amazon.com/dp/B0SATIN001?tag=other-20", "heather-20");
    expect(result.url, contains("tag=other-20"));
    expect(result.note, contains("existing tag"));
  });
}
