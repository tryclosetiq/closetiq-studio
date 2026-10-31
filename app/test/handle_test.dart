import "package:closetiq_studio/domain/handle_rules.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("accepts a normal handle and rejects reserved or messy ones", () {
    expect(handleIsValid("@Heather"), isTrue);
    expect(normalizeHandle("@Heather"), "heather");
    expect(handleError("go"), "That handle is reserved.");
    expect(handleError("a"), contains("3–30"));
    expect(handleError("has space"), isNotNull);
    expect(handleError(""), "Choose a storefront handle.");
  });
}
