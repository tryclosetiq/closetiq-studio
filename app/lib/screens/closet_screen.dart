import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../app_state.dart";
import "../domain/amazon_tag.dart";
import "../domain/models.dart";
import "../theme/brand.dart";

class ClosetScreen extends StatelessWidget {
  const ClosetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final snapshot = state.store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: Text("Closet", style: Theme.of(context).textTheme.displaySmall)),
              FilledButton.icon(
                key: const Key("add-item"),
                onPressed: () => showAddItemSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Add item"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Amazon items and anything else. A piece with no affiliate link is saved as not monetized.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Brand.muted),
          ),
          const SizedBox(height: 16),
          if (snapshot.garments.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text("Your closet is empty. Paste a product link or add one by hand."))
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 520 ? 3 : 2);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                itemCount: snapshot.garments.length,
                itemBuilder: (context, index) => _GarmentTile(garment: snapshot.garments[index]),
              );
            }),
        ],
      ),
    );
  }
}

class _GarmentTile extends StatelessWidget {
  const _GarmentTile({required this.garment});

  final Garment garment;

  @override
  Widget build(BuildContext context) {
    final badge = garment.notMonetized ? "Not monetized" : (garment.source == "amazon" ? "Amazon" : "Link");
    return InkWell(
      onTap: () => _open(context),
      child: Container(
        decoration: studioCard(radius: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Color(garment.swatch),
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(8),
                child: garment.displayImage.isEmpty
                    ? const Text("EXAMPLE", style: TextStyle(color: Colors.white70, fontSize: 11))
                    : Image.network(garment.displayImage, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(garment.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("${garment.priceText ?? "No price"} · $badge", style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final state = StudioScope.of(context);
    final looks = state.store!.snapshot.outfits.where((outfit) => outfit.itemIds.contains(garment.id)).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(garment.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(garment.notMonetized ? "Not monetized · no affiliate link" : (garment.affiliateUrl ?? "")),
            const SizedBox(height: 8),
            Text("In ${looks.length} ${looks.length == 1 ? "look" : "looks"}. Adding it on the storefront uses the same list."),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: looks.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                    },
              child: Text(looks.isEmpty ? "Not in a look yet" : "In ${looks.map((look) => look.name).join(", ")}"),
            ),
            TextButton(
              onPressed: () async {
                await state.store!.deleteGarment(garment.id);
                await state.refresh();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("Delete from closet", style: TextStyle(color: Brand.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAddItemSheet(BuildContext context, {String? outfitId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Brand.cream,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _AddItemForm(outfitId: outfitId),
    ),
  );
}

class _AddItemForm extends StatefulWidget {
  const _AddItemForm({this.outfitId});

  final String? outfitId;

  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _link = TextEditingController();
  String? _imageUrl;
  List<int>? _photo;
  String _message = "";
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _price.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() { _busy = true; _message = "Reading the page…"; });
    final result = await StudioScope.of(context).importUrl(_url.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.ok) {
        _name.text = result.name ?? _name.text;
        _price.text = result.priceText ?? _price.text;
        _imageUrl = result.imageUrl ?? _imageUrl;
        if (_link.text.trim().isEmpty) _link.text = result.sourceUrl;
        _message = "Filled from the page. Check the details, then save.";
      } else {
        if (_link.text.trim().isEmpty) _link.text = _url.text.trim();
        _message = result.message;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _message = "Add a name to save this piece.");
      return;
    }
    final state = StudioScope.of(context);
    final tag = tagAmazon(_link.text, state.store!.snapshot.settings.amazonTag);
    setState(() => _busy = true);
    try {
      final garment = await state.store!.addGarment(GarmentDraft(
        name: _name.text,
        source: _imageUrl != null ? "import" : (_link.text.contains("amazon.") ? "amazon" : "manual"),
        priceText: _price.text,
        productUrl: _url.text.trim().isEmpty ? _link.text : _url.text,
        affiliateUrl: _link.text,
        imageUrl: _imageUrl,
        photoBytes: _photo,
        asin: tag.asin,
      ));
      if (widget.outfitId != null) {
        await state.store!.addPiece(widget.outfitId!, garment.id);
      }
      await state.refresh();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() { _busy = false; _message = "$error"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagNote = tagAmazon(_link.text, StudioScope.of(context).store?.snapshot.settings.amazonTag ?? "").note;
    final monetized = _link.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.outfitId == null ? "Add an item" : "Add a piece to this look", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text("Paste a product URL to fill the photo, name and price. If the page can't be read, use the fields below."),
          const SizedBox(height: 12),
          TextField(key: const Key("import-url"), controller: _url, decoration: const InputDecoration(labelText: "Product URL"), keyboardType: TextInputType.url),
          const SizedBox(height: 8),
          OutlinedButton(key: const Key("import-go"), onPressed: _busy ? null : _import, child: const Text("Import from URL")),
          const SizedBox(height: 12),
          TextField(key: const Key("item-name"), controller: _name, decoration: const InputDecoration(labelText: "Name")),
          const SizedBox(height: 8),
          TextField(controller: _price, decoration: const InputDecoration(labelText: "Price (optional)")),
          const SizedBox(height: 8),
          TextField(controller: _link, decoration: const InputDecoration(labelText: "Your affiliate link (optional)"), onChanged: (_) => setState(() {})),
          if (tagNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tagNote, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 8),
          Text(monetized ? "Affiliate link will be tracked." : "Not monetized — no affiliate link yet.", style: TextStyle(color: monetized ? Brand.positive : Brand.danger, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (!mounted) return;
              setState(() => _photo = bytes);
            },
            child: Text(_photo == null ? "Add your own photo" : "Photo attached"),
          ),
          if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message)),
          const SizedBox(height: 12),
          FilledButton(key: const Key("item-save"), onPressed: _busy ? null : _save, child: const Text("Save to closet")),
        ],
      ),
    );
  }
}
