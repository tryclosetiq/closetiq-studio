import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../domain/models.dart";
import "../theme/brand.dart";
import "../widgets/studio_shell.dart";
import "share_sheet.dart";

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({super.key});

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  var _filter = "all";

  static const _people = <(String, String, int, String)>[
    ("My photo", "photo", 0xFFC4A574, "EXAMPLE"),
    ("AI me", "ai_self", 0xFF8D7355, "EXAMPLE"),
    ("Studio neutral", "default", 0xFFB08A62, "preset"),
    ("Editorial", "ai_model", 0xFF5C4638, "EXAMPLE"),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _people.where((person) => _filter == "all" || person.$2 == _filter).toList();
    return _page(
      context,
      title: "My Models",
      hint: "Your photos, AI versions of you, and reusable AI models. Tap one for options.",
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: studioCard(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("My Reference Photos", style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                "Full-length photos guide your natural proportions. Styled pictures should still look recognisably like you.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              const SectionLabel("Face · close-up portrait (identity)"),
              const SizedBox(height: 6),
              SizedBox(
                height: 96,
                child: DashedAddTile(label: "+ Portrait", onTap: () => studioLater(context, "Adding a face portrait arrives with model generation. Nothing is charged.")),
              ),
              const SizedBox(height: 10),
              const SectionLabel("Body · full-length photos (proportions)"),
              const SizedBox(height: 6),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (index, label) in const [(0, "Reference 1"), (1, "Reference 2"), (2, "Reference 3")])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 88,
                          child: SwatchCard(
                            color: const [0xFFC4A574, 0xFFB08A62, 0xFF8D7355][index],
                            label: label,
                            badge: index == 0 ? "primary" : "EXAMPLE",
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => studioLater(context, "Style me in an outfit arrives with try-on. Nothing is charged."),
                child: const Text("Style me in an outfit (pose, hair, scene)"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (id, label) in const [("all", "All"), ("photo", "My photos"), ("ai_self", "AI me"), ("ai_model", "AI models"), ("default", "Presets")])
              _chip(label, _filter == id, () => setState(() => _filter = id)),
          ],
        ),
        const SizedBox(height: 12),
        _tileGrid([
          DashedAddTile(label: "+ Add my photo", onTap: () => studioLater(context, "Model photos arrive with the connected studio. Add clothing from the Clothing tab.")),
          DashedAddTile(
            tileKey: const Key("open-generate-model"),
            label: "✦ Generate model",
            onTap: () => showGenerateModelSheet(context),
          ),
          for (final person in visible)
            SwatchCard(
              color: person.$3,
              label: person.$1,
              badge: person.$4,
              onTap: () => studioLater(context, "Model options arrive with generation. Use in Try-On is not connected, so nothing is charged."),
            ),
        ]),
      ],
    );
  }
}

class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key});

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  var _quality = "fast";
  String? _model;
  String? _garment;

  @override
  Widget build(BuildContext context) {
    final snapshot = StudioScope.of(context).store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final credits = _quality == "fast" ? 1 : 2;
    return _page(
      context,
      title: "AI Try-On",
      hint: "Optional. See the look on you or an AI model before you share. You'll see the cost before it runs. It isn't connected in this version, so nothing is charged.",
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: studioCard(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel("Model"),
              const SizedBox(height: 6),
              _strip(const ["My photo", "Studio neutral", "Editorial"], _model, (value) => setState(() => _model = value)),
              const SizedBox(height: 10),
              const SectionLabel("Clothing"),
              const SizedBox(height: 6),
              _strip(snapshot.garments.map((garment) => garment.name).toList(), _garment, (value) => setState(() => _garment = value)),
              const SizedBox(height: 10),
              const SectionLabel("Quality"),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _chip("Fast · 1 credit", _quality == "fast", () => setState(() => _quality = "fast")),
                  _chip("Balanced · 2 credits", _quality == "balanced", () => setState(() => _quality = "balanced")),
                ],
              ),
              const SizedBox(height: 8),
              Text("$credits credit${credits == 1 ? "" : "s"} for one image. Skip this if you just want to share your pieces."),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => studioLater(context, "Try-on runs through FASHN in a later phase. You'll see the credit cost before it runs. Nothing is charged in this version."),
                child: const Text("Try it on · credits shown first"),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: snapshot.outfits.isEmpty
                    ? null
                    : () => showShareSheet(context, outfitId: snapshot.outfits.first.id, title: snapshot.outfits.first.name),
                child: const Text("Share without try-on"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _idea = TextEditingController();

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _page(
      context,
      title: "Discover",
      hint: "Describe what you want — style, colors, occasion, budget, must-have pieces. The AI stylist will create outfit ideas. It isn't connected in this version.",
      children: [
        TextField(
          controller: _idea,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "e.g. Fall date night, cozy and chic"),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final example in const ["5 trendy fall outfits under \$100 each", "3 office looks under \$150", "4 date-night outfits under \$120"])
              _chip(example, false, () => setState(() => _idea.text = example)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => studioLater(context, "Soon the AI stylist will find real products that match your idea. Nothing is charged."),
          child: const Text("AI stylist · coming soon"),
        ),
        const SizedBox(height: 12),
        Text(
          "Product photos and prices will come from the retailer. As an Amazon Associate I earn from qualifying purchases.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class CollagesScreen extends StatelessWidget {
  const CollagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = StudioScope.of(context).store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    return _page(
      context,
      title: "Collages",
      hint: "Clothing only, you + outfit, an AI model + outfit, or a finished image you import. Tap one to share it.",
      children: [
        OutlinedButton(
          onPressed: () => studioLater(context, "The collage editor and Facebook queue arrive in a later update. Share a saved outfit in the meantime."),
          child: const Text("Facebook queue · coming soon"),
        ),
        const SizedBox(height: 12),
        _tileGrid([
          DashedAddTile(label: "+ New collage", onTap: () => studioLater(context, "The collage canvas arrives in a later update.")),
          for (final page in snapshot.pages)
            SwatchCard(
              color: page.swatch,
              label: page.title,
              badge: "EXAMPLE",
              onTap: () => showShareSheet(context, outfitId: page.outfitId, title: page.title),
            ),
        ], columns: 2),
      ],
    );
  }
}

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _page(
      context,
      title: "My Photos",
      hint: "Everything you've generated. Try-on results will land here. Nothing has been generated in this version.",
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: Text("No generated photos yet.")),
        ),
      ],
    );
  }
}

class OutfitsScreen extends StatelessWidget {
  const OutfitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = StudioScope.of(context).store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    return _page(
      context,
      title: "Saved Outfits",
      hint: "Group clothing into outfits and keep the links together.",
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _newOutfit(context),
                child: const Text("+ New outfit"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => context.go("/storefront"), child: const Text("Storefront"))),
          ],
        ),
        const SizedBox(height: 12),
        for (final (index, outfit) in snapshot.outfits.indexed)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: studioCard(radius: 14),
            child: Row(
              children: [
                Container(width: 44, height: 56, decoration: BoxDecoration(color: Color(snapshot.pageFor(outfit.id)?.swatch ?? 0xFFB08A62), borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(outfit.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text("${outfit.itemIds.length} pieces", style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  key: index == 0 ? const Key("open-share-sheet") : null,
                  tooltip: "Share",
                  onPressed: () => showShareSheet(context, outfitId: outfit.id, title: outfit.name, caption: outfit.caption),
                  icon: const Icon(Icons.ios_share),
                ),
              ],
            ),
          ),
        if (snapshot.posts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text("Reminders", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("Saved reminders only. Nothing is auto-posted.", style: Theme.of(context).textTheme.bodySmall),
          for (final post in snapshot.posts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(post.title),
              subtitle: Text(formatTime(post.when)),
            ),
        ],
      ],
    );
  }

  Future<void> _newOutfit(BuildContext context) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.cream,
      builder: (context) => const _NewOutfitSheet(),
    );
    if (name == null || !context.mounted) return;
    final state = StudioScope.of(context);
    await state.store!.createLook(name: name, idea: name, itemIds: const [], caption: "", published: false);
    await state.refresh();
  }
}

class _NewOutfitSheet extends StatefulWidget {
  const _NewOutfitSheet();

  @override
  State<_NewOutfitSheet> createState() => _NewOutfitSheetState();
}

class _NewOutfitSheetState extends State<_NewOutfitSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("New outfit", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text("Name the look. Add pieces from Clothing, or share it once it has items."),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Outfit name", hintText: "Saturday espresso")),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, _name.text.trim().isEmpty ? "New outfit" : _name.text.trim()),
            child: const Text("Save outfit"),
          ),
        ],
      ),
    );
  }
}

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final snapshot = StudioScope.of(context).store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final outfit = snapshot.outfits.isEmpty ? null : snapshot.outfits.first;
    return _page(
      context,
      title: "Reels",
      hint: "Pick a saved outfit and a template. Rendering a 9:16 reel arrives in a later update, and it will be free.",
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: studioCard(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel("Outfit"),
              const SizedBox(height: 6),
              Text(outfit?.name ?? "Save an outfit first"),
              const SizedBox(height: 10),
              const SectionLabel("Template"),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final template in const ["Outfit transition", "Mirror", "Shop the look"]) _chip(template, template == "Outfit transition", () {}),
              ]),
              const SizedBox(height: 10),
              const SectionLabel("Length"),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final length in const ["10 s", "15 s", "30 s"]) _chip(length, length == "15 s", () {}),
              ]),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => studioLater(context, "Reel rendering arrives in a later update. Share the outfit in the meantime."),
                child: const Text("Render video · coming soon"),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: outfit == null ? null : () => showShareSheet(context, outfitId: outfit.id, title: outfit.name),
                child: const Text("Share this outfit"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showGenerateModelSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Brand.card,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: const _GenerateModelSheet(),
    ),
  );
}

class _GenerateModelSheet extends StatefulWidget {
  const _GenerateModelSheet();

  @override
  State<_GenerateModelSheet> createState() => _GenerateModelSheetState();
}

class _GenerateModelSheetState extends State<_GenerateModelSheet> {
  static const _starts = <(String, String)>[
    ("Studio neutral", "woman in her 30s, medium build, long brown hair, soft smile, neutral background"),
    ("Editorial", "editorial model, sharp cheekbones, slicked hair, grey seamless backdrop"),
    ("Curvy classic", "curvy woman in her 30s, olive skin, dark curly hair, confident pose, light beige backdrop"),
    ("Minimal street", "woman in her 20s, athletic build, short black hair, relaxed pose, plain white wall"),
    ("Elegant", "elegant woman in her 40s, silver-streaked hair in a low bun, graceful posture, cream studio background"),
    ("Fresh", "young woman with red hair and freckles, natural look, standing straight, pale pink backdrop"),
  ];

  final _prompt = TextEditingController();
  final _name = TextEditingController();
  var _quality = "fast";
  var _looksLikeMe = false;

  @override
  void dispose() {
    _prompt.dispose();
    _name.dispose();
    super.dispose();
  }

  int get _credits => (_quality == "fast" ? 1 : 2) + (_looksLikeMe ? 3 : 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Generate a model", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const SectionLabel("Quick starts"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final start in _starts)
                  _chip(start.$1, _prompt.text == start.$2, () {
                    setState(() {
                      _prompt.text = start.$2;
                      if (_name.text.isEmpty) _name.text = start.$1;
                    });
                  }),
              ],
            ),
            const SizedBox(height: 14),
            const SectionLabel("Describe the model"),
            const SizedBox(height: 6),
            TextField(
              controller: _prompt,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(hintText: "e.g. woman in her 30s, medium build, long brown hair, soft smile, neutral background"),
            ),
            const SizedBox(height: 12),
            const SectionLabel("Name"),
            const SizedBox(height: 6),
            TextField(controller: _name, decoration: const InputDecoration(hintText: "Model name")),
            const SizedBox(height: 12),
            const SectionLabel("Look like me (optional, +3 credits)"),
            const SizedBox(height: 6),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (label, color) in const [("Reference 1", 0xFFC4A574), ("Reference 2", 0xFFB08A62), ("Reference 3", 0xFF8D7355)])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 72,
                        child: SwatchCard(
                          color: color,
                          label: label,
                          badge: "EXAMPLE",
                          onTap: () => setState(() => _looksLikeMe = !_looksLikeMe),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionLabel("Quality"),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _chip("Fast · 1 credit", _quality == "fast", () => setState(() => _quality = "fast")),
                _chip("Balanced · 2 credits", _quality == "balanced", () => setState(() => _quality = "balanced")),
              ],
            ),
            const SizedBox(height: 8),
            Text("$_credits credit${_credits == 1 ? "" : "s"} for one image${_looksLikeMe ? " (includes face reference)" : ""}."),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => studioLater(
                context,
                "Generating a model will show this credit cost first. It isn't connected in this version, so nothing is charged.",
              ),
              child: const Text("Generate"),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tileGrid(List<Widget> tiles, {int columns = 3}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tile in tiles) SizedBox(width: width, height: width / 0.72, child: tile),
        ],
      );
    },
  );
}

Widget _page(BuildContext context, {required String title, required String hint, required List<Widget> children}) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(hint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Brand.muted)),
      const SizedBox(height: 12),
      ...children,
    ],
  );
}

Widget _chip(String label, bool on, VoidCallback tap) {
  return FilterChip(
    label: Text(label),
    selected: on,
    showCheckmark: false,
    selectedColor: Brand.gold,
    backgroundColor: Brand.card,
    labelStyle: TextStyle(color: on ? Brand.goldInk : Brand.ink, fontWeight: FontWeight.w600, fontSize: 13),
    side: BorderSide(color: on ? Brand.gold : Brand.line),
    onSelected: (_) => tap(),
  );
}

Widget _strip(List<String> labels, String? selected, ValueChanged<String> onPick) {
  return SizedBox(
    height: 86,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final (index, label) in labels.indexed)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 72,
              child: SwatchCard(
                color: Brand.swatches[index % Brand.swatches.length],
                label: label,
                badge: selected == label ? "on" : null,
                onTap: () => onPick(label),
              ),
            ),
          ),
      ],
    ),
  );
}
