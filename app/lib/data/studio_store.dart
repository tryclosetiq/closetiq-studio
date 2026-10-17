import "../domain/models.dart";
import "demo_studio.dart";

abstract class StudioStore {
  StudioSnapshot get snapshot;

  Future<void> reload();
  Future<void> saveSettings(CreatorSettings settings);
  Future<Garment> addGarment(GarmentDraft draft);
  Future<void> deleteGarment(String id);
  Future<String> createLook({
    required String name,
    required String idea,
    required List<String> itemIds,
    required String caption,
    required bool published,
  });
  Future<void> addPiece(String outfitId, String garmentId);
  Future<void> removePiece(String outfitId, String garmentId);
  Future<void> setHidden(String outfitId, String garmentId, bool hidden);
  Future<void> setPublished(String outfitId, bool published);
  Future<void> addCollection(String name);
  Future<void> setCollectionHidden(String id, bool hidden);
  Future<ScheduledPost> schedule({
    required String title,
    required DateTime when,
    required String caption,
    required List<String> networks,
    String? outfitId,
  });
}

class DemoStore implements StudioStore {
  DemoStore(this.demo);

  final DemoStudio demo;

  @override
  StudioSnapshot get snapshot => demo.snapshot;

  @override
  Future<void> reload() async {}

  @override
  Future<void> saveSettings(CreatorSettings settings) async => demo.saveSettings(settings);

  @override
  Future<Garment> addGarment(GarmentDraft draft) async => demo.addGarment(draft);

  @override
  Future<void> deleteGarment(String id) async => demo.deleteGarment(id);

  @override
  Future<String> createLook({
    required String name,
    required String idea,
    required List<String> itemIds,
    required String caption,
    required bool published,
  }) async {
    return demo.createLook(name: name, idea: idea, itemIds: itemIds, caption: caption, published: published);
  }

  @override
  Future<void> addPiece(String outfitId, String garmentId) async => demo.addPiece(outfitId, garmentId);

  @override
  Future<void> removePiece(String outfitId, String garmentId) async => demo.removePiece(outfitId, garmentId);

  @override
  Future<void> setHidden(String outfitId, String garmentId, bool hidden) async => demo.setHidden(outfitId, garmentId, hidden);

  @override
  Future<void> setPublished(String outfitId, bool published) async => demo.setPublished(outfitId, published);

  @override
  Future<void> addCollection(String name) async => demo.addCollection(name);

  @override
  Future<void> setCollectionHidden(String id, bool hidden) async => demo.setCollectionHidden(id, hidden);

  @override
  Future<ScheduledPost> schedule({
    required String title,
    required DateTime when,
    required String caption,
    required List<String> networks,
    String? outfitId,
  }) async {
    return demo.schedule(title: title, when: when, caption: caption, networks: networks, outfitId: outfitId);
  }
}
