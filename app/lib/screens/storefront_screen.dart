import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:qr_flutter/qr_flutter.dart";

import "../app_state.dart";
import "../domain/models.dart";
import "../theme/brand.dart";
import "closet_screen.dart";

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  bool _preview = false;

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final snapshot = state.store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final handle = snapshot.settings.handle;
    final url = handle == null ? "" : state.config.storefrontUrl(handle);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Text("Storefront", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            "Your public shopping page for your bios. Everything you publish from the Studio appears there.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Brand.muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: studioCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Your link", style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(url.isEmpty ? "Choose a handle to publish" : url.replaceFirst("https://", ""), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      key: const Key("copy-storefront"),
                      onPressed: url.isEmpty
                          ? null
                          : () async {
                              try {
                                await Clipboard.setData(ClipboardData(text: url));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link copied.")));
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copy failed. Select the link and copy it manually.")));
                                }
                              }
                            },
                      child: const Text("Copy link"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key("storefront-qr"),
                      onPressed: url.isEmpty ? null : () => _qr(context, url),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text("QR"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _tab("Edit", !_preview, () => setState(() => _preview = false))),
              const SizedBox(width: 8),
              Expanded(child: _tab("Preview", _preview, () => setState(() => _preview = true))),
            ],
          ),
          const SizedBox(height: 14),
          if (_preview) _PublicPreview(snapshot: snapshot) else _Editor(snapshot: snapshot),
        ],
    );
  }

  Widget _tab(String label, bool on, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? Brand.card : Brand.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Brand.line),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: on ? Brand.ink : Brand.muted)),
      ),
    );
  }

  void _qr(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Brand.cream,
        title: const Text("Storefront QR"),
        content: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: url, size: 200, backgroundColor: Colors.white),
              const SizedBox(height: 8),
              Text(url, textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.snapshot});

  final StudioSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    return Column(
      children: [
        Material(
          color: Brand.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Brand.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final collection in snapshot.collections)
                SwitchListTile(
                  title: Text(collection.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(collection.detail.isEmpty ? "${collection.lookCount} looks" : collection.detail),
                  value: !collection.hidden,
                  activeThumbColor: Brand.gold,
                  onChanged: (value) async {
                    await state.store!.setCollectionHidden(collection.id, !value);
                    await state.refresh();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: snapshot.pages.isEmpty ? null : () => _editLook(context, snapshot.pages.first),
                child: const Text("Edit a look"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key("add-collection"),
                onPressed: () async {
                  await state.store!.addCollection("New collection");
                  await state.refresh();
                },
                child: const Text("+ Collection"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final page in snapshot.pages) _lookRow(context, page),
      ],
    );
  }

  Widget _lookRow(BuildContext context, ShopPage page) {
    final state = StudioScope.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: Color(page.swatch), borderRadius: BorderRadius.circular(10))),
      title: Text(page.title),
      subtitle: Text("${page.pieceCount} pieces · ${page.published ? "Live" : "Draft"}${page.imageNeedsRerender ? " · cover will refresh later" : ""}"),
      trailing: Switch(
        value: page.published,
        activeThumbColor: Brand.gold,
        onChanged: (value) async {
          await state.store!.setPublished(page.outfitId, value);
          await state.refresh();
        },
      ),
      onTap: () => _editLook(context, page),
    );
  }

  Future<void> _editLook(BuildContext context, ShopPage page) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      builder: (context) => _LookEditor(outfitId: page.outfitId),
    );
  }
}

class _LookEditor extends StatelessWidget {
  const _LookEditor({required this.outfitId});

  final String outfitId;

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final snapshot = state.store!.snapshot;
    final outfit = snapshot.outfit(outfitId);
    final pieces = snapshot.pieces(outfitId);
    final missing = snapshot.garments.where((garment) => !(outfit?.itemIds.contains(garment.id) ?? false)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(outfit?.name ?? "Look", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text("This list is the outfit. Hiding a piece keeps it in the outfit and takes it off the public page."),
          const SizedBox(height: 8),
          for (final piece in pieces)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(piece.garment.name),
              subtitle: Text(piece.garment.notMonetized ? "Not monetized" : (piece.garment.priceText ?? "Affiliate link")),
              value: !piece.hidden,
              onChanged: (value) async {
                await state.store!.setHidden(outfitId, piece.garment.id, !value);
                await state.refresh();
              },
            ),
          for (final garment in missing)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  await state.store!.addPiece(outfitId, garment.id);
                  await state.refresh();
                },
                child: Text("Add ${garment.name}"),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => showAddItemSheet(context, outfitId: outfitId),
            child: const Text("Add a new piece"),
          ),
        ],
      ),
    );
  }
}

class _PublicPreview extends StatelessWidget {
  const _PublicPreview({required this.snapshot});

  final StudioSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final looks = snapshot.pages.where((page) => page.published && page.listed).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: studioCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("@${snapshot.settings.handle ?? "handle"}", style: Theme.of(context).textTheme.bodySmall),
          Text(snapshot.settings.storefrontTitle, style: Theme.of(context).textTheme.headlineMedium),
          if ((snapshot.settings.subtitle ?? "").isNotEmpty) Text(snapshot.settings.subtitle!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (looks.isEmpty) const Text("Nothing is live yet. Turn a look on to publish it.")
          else
            for (final page in looks) ...[
              Text(page.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              for (final piece in snapshot.pieces(page.outfitId, includeHidden: false))
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text("· ${piece.garment.name}${piece.garment.notMonetized ? " (no affiliate link)" : ""}"),
                ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          Text(snapshot.settings.disclosure, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
