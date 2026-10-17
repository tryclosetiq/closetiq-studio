import "package:closetiq_studio/data/demo_studio.dart";
import "package:closetiq_studio/domain/models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  DemoStudio studio() {
    return DemoStudio(const StudioSnapshot(
      settings: CreatorSettings(displayName: "A", email: "a@b.co", onboardingComplete: true),
      garments: [
        Garment(id: "g1", name: "Coat", affiliateUrl: "https://shop.example.com/coat"),
        Garment(id: "g2", name: "Hat"),
      ],
      outfits: [Outfit(id: "o1", name: "Look")],
      meta: [],
      pages: [ShopPage(outfitId: "o1", slug: "look000001", title: "Look")],
      collections: [],
      posts: [],
      attention: [],
      clicks7d: 0,
      clicksPrev7d: 0,
    ));
  }

  test("adding a piece from either side updates the outfit and the storefront list", () {
    final book = studio();
    book.addPiece("o1", "g1");
    expect(book.snapshot.outfit("o1")!.itemIds, ["g1"]);
    expect(book.snapshot.pieces("o1").single.garment.name, "Coat");
    expect(book.snapshot.pageFor("o1")!.imageNeedsRerender, isTrue);
  });

  test("hiding a storefront piece keeps it on the outfit", () {
    final book = studio();
    book.addPiece("o1", "g1");
    book.setHidden("o1", "g1", true);
    expect(book.snapshot.outfit("o1")!.itemIds, ["g1"]);
    expect(book.snapshot.pieces("o1", includeHidden: false), isEmpty);
    expect(book.snapshot.pieces("o1").single.hidden, isTrue);
  });

  test("removing a piece drops it from the outfit and the public list", () {
    final book = studio();
    book.addPiece("o1", "g1");
    book.addPiece("o1", "g2");
    book.removePiece("o1", "g1");
    expect(book.snapshot.outfit("o1")!.itemIds, ["g2"]);
    expect(book.snapshot.pieces("o1").map((piece) => piece.garment.id), ["g2"]);
  });

  test("a new look starts unpublished and can be turned on", () {
    final book = studio();
    final id = book.createLook(name: "Friday", idea: "Office", itemIds: ["g2"]);
    expect(book.snapshot.pageFor(id)!.published, isFalse);
    expect(book.snapshot.pieces(id).single.garment.notMonetized, isTrue);
    book.setPublished(id, true);
    expect(book.snapshot.pageFor(id)!.published, isTrue);
  });
}
