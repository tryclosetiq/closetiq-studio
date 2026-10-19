import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../domain/models.dart";
import "../theme/brand.dart";

class CreateFlowScreen extends StatefulWidget {
  const CreateFlowScreen({super.key});

  @override
  State<CreateFlowScreen> createState() => _CreateFlowScreenState();
}

class _CreateFlowScreenState extends State<CreateFlowScreen> {
  int _step = 0;
  final _idea = TextEditingController();
  final _selected = <String>{};
  final _formats = <String>{"Collage", "Reel"};
  bool _storefront = true;
  bool _amazonPack = false;
  var _when = "Tonight 6:30 PM";
  String _caption = "";

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  List<Garment> _pieces(StudioSnapshot snapshot) {
    return snapshot.garments.where((garment) => _selected.contains(garment.id)).toList();
  }

  void _ensureCaption(StudioSnapshot snapshot) {
    if (_caption.trim().isNotEmpty) return;
    _caption = draftCaption(idea: _idea.text, pieces: _pieces(snapshot), disclosure: snapshot.settings.disclosure);
  }

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final snapshot = state.store?.snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (_step == 0) {
                      context.go("/home");
                    } else {
                      setState(() => _step -= 1);
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_step == 0 ? "Home" : "Back"),
                ),
                const Spacer(),
                if (!wide) Text("STEP ${_step + 1} OF 4", style: Theme.of(context).textTheme.bodySmall),
                if (wide) const Text("Autosaved as draft", style: TextStyle(color: Brand.muted)),
              ],
            ),
          ),
          _stepIndicator(snapshot, wide),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_step == 0) _ideaStep(context),
                if (_step == 1) _pickStep(snapshot),
                if (_step == 2) _tryStep(snapshot),
                if (_step == 3) _shareStep(context, snapshot, wide),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _steps = <(int, String, String?)>[
    (0, "Idea", null),
    (1, "Pick pieces", null),
    (2, "Try it on", "optional"),
    (3, "Make & share", null),
  ];

  bool _canOpen(int index) {
    if (index <= _step) return true;
    if (_selected.isEmpty && _step < 2) return false;
    // Try-on is optional, so Make & share stays open once pieces are chosen.
    return index == 2 || index == 3;
  }

  void _goToStep(int index, StudioSnapshot snapshot) {
    if (index == _step || !_canOpen(index)) return;
    setState(() {
      if (index == 3) _ensureCaption(snapshot);
      _step = index;
    });
  }

  Widget _stepIndicator(StudioSnapshot snapshot, bool wide) {
    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Row(
          children: [
            for (final (index, label, hint) in _steps)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text("${index + 1}  $label${hint == null ? "" : " · $hint"}"),
                  selected: _step == index,
                  onSelected: _canOpen(index) ? (_) => _goToStep(index, snapshot) : null,
                ),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          for (final (index, label, hint) in _steps)
            Expanded(
              child: InkWell(
                onTap: _canOpen(index) ? () => _goToStep(index, snapshot) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _step == index ? FontWeight.w700 : FontWeight.w500,
                          color: _step == index ? Brand.ink : Brand.muted,
                        ),
                      ),
                      SizedBox(
                        height: 14,
                        child: hint == null
                            ? null
                            : const Text("optional", style: TextStyle(fontSize: 10, height: 1.2, color: Brand.muted)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= _step ? Brand.ink : Brand.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ideaStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("What's the look?", style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text("Describe the vibe. We'll use it for your title and caption, then you'll pick pieces from your closet."),
        const SizedBox(height: 14),
        TextField(
          key: const Key("idea-field"),
          controller: _idea,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: "e.g. Fall date night, cozy and chic"),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final chip in ["Under \$100", "Office", "Date night", "Restyle"])
              ActionChip(label: Text(chip), onPressed: () => setState(() => _idea.text = _idea.text.trim().isEmpty ? chip : "${_idea.text.trim()}, $chip")),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => _later(context, "Voice input is not in this version."), child: const Text("Speak it · coming soon")),
            OutlinedButton(
              onPressed: () => _later(context, "Soon the AI stylist will find real products that match your idea."),
              child: const Text("AI stylist · coming soon"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Phase 1 only names the look. When Discover / AI stylist search is wired
        // in phase 2, this button should go back to "Show me outfits".
        FilledButton(
          key: const Key("idea-continue"),
          onPressed: () => setState(() => _step = 1),
          child: const Text("Pick from my closet"),
        ),
      ],
    );
  }

  Widget _pickStep(StudioSnapshot snapshot) {
    final chosen = _pieces(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Pick your pieces", style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        Text("${chosen.length} ${chosen.length == 1 ? "piece" : "pieces"} selected"),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final garment in snapshot.garments)
              FilterChip(
                label: Text(garment.name),
                selected: _selected.contains(garment.id),
                onSelected: (value) => setState(() {
                  if (value) {
                    _selected.add(garment.id);
                  } else {
                    _selected.remove(garment.id);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key("pieces-continue"),
          onPressed: _selected.isEmpty ? null : () => setState(() => _step = 2),
          child: const Text("Try it on"),
        ),
      ],
    );
  }

  Widget _tryStep(StudioSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Try it on (optional)", style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 8),
        const Text("See the look on you or an AI model before you share. It uses credits, and you'll see the cost before it runs. Skip it if you just want to share your pieces."),
        const SizedBox(height: 6),
        Text("It isn't connected in this version, so nothing is charged.", style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Container(
          height: 280,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Brand.soft, borderRadius: BorderRadius.circular(18)),
          child: Text(
            _pieces(snapshot).map((garment) => garment.name).join("\n"),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.muted),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _later(context, "Try-on runs through FASHN in a later phase. You'll see the credit cost before it runs. Nothing is charged in this version."),
          child: const Text("Try it on · credits shown first"),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key("try-continue"),
          onPressed: () => setState(() { _ensureCaption(snapshot); _step = 3; }),
          child: const Text("Skip try-on"),
        ),
      ],
    );
  }

  Widget _shareStep(BuildContext context, StudioSnapshot snapshot, bool wide) {
    _ensureCaption(snapshot);
        final panel = _SharePanel(
      caption: _caption,
      formats: _formats,
      storefront: _storefront,
      amazonPack: _amazonPack,
      when: _when,
      wide: wide,
      onFormat: (format) => setState(() {
        if (_formats.contains(format) && _formats.length > 1) {
          _formats.remove(format);
        } else {
          _formats.add(format);
        }
      }),
      onStorefront: (value) => setState(() => _storefront = value),
      onAmazon: (value) => setState(() => _amazonPack = value),
      onWhen: (value) => setState(() => _when = value),
      onSchedule: () => _schedule(context, snapshot),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Make & share", style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final format in ["Collage", "Reel", "Story"])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _FormatCard(label: format, selected: _formats.contains(format), onTap: () => setState(() {
                    if (_formats.contains(format) && _formats.length > 1) {
                      _formats.remove(format);
                    } else {
                      _formats.add(format);
                    }
                  })),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text("CAPTION · INSTAGRAM", style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        TextFormField(
          key: const Key("caption-field"),
          initialValue: _caption,
          maxLines: 5,
          onChanged: (value) => _caption = value,
        ),
        const SizedBox(height: 12),
        if (wide) panel else FilledButton(key: const Key("open-share-sheet"), onPressed: () => _sheet(context, panel), child: const Text("Share this look")),
      ],
    );
  }

  Future<void> _sheet(BuildContext context, Widget panel) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.card,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SingleChildScrollView(child: panel),
      ),
    );
  }

  Future<void> _schedule(BuildContext context, StudioSnapshot snapshot) async {
    final state = StudioScope.of(context);
    final title = _idea.text.trim().isEmpty ? "New look" : _idea.text.trim().split("\n").first;
    final short = title.length > 48 ? title.substring(0, 48) : title;
    final when = _when.startsWith("Tomorrow")
        ? DateTime.now().add(const Duration(days: 1, hours: 9))
        : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 18, 30);
    final id = await state.store!.createLook(
      name: short,
      idea: _idea.text,
      itemIds: _selected.toList(),
      caption: _caption,
      published: _storefront,
    );
    await state.store!.schedule(
      title: short,
      when: when.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(hours: 2)) : when,
      caption: _caption,
      networks: [
        if (_formats.contains("Reel")) "instagram",
        if (_formats.contains("Story")) "instagram",
        "storefront",
      ],
      outfitId: id,
    );
    await state.refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder saved. Nothing is auto-posted.")));
    context.go("/schedule");
  }

  void _later(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = {"Collage": 0xFFB08A62, "Reel": 0xFF3A3128, "Story": 0xFFC5BEA8};
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(color: Color(colors[label] ?? 0xFFB08A62), borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(10),
        alignment: Alignment.bottomLeft,
        child: Text("$label${selected ? "  ✓" : ""}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SharePanel extends StatelessWidget {
  const _SharePanel({
    required this.caption,
    required this.formats,
    required this.storefront,
    required this.amazonPack,
    required this.when,
    required this.wide,
    required this.onFormat,
    required this.onStorefront,
    required this.onAmazon,
    required this.onWhen,
    required this.onSchedule,
  });

  final String caption;
  final Set<String> formats;
  final bool storefront;
  final bool amazonPack;
  final String when;
  final bool wide;
  final ValueChanged<String> onFormat;
  final ValueChanged<bool> onStorefront;
  final ValueChanged<bool> onAmazon;
  final ValueChanged<String> onWhen;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final appUrl = state.store?.snapshot.settings.appStoreUrl ?? state.config.closetIqAppStoreUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(wide ? "SHARE TO" : "Share this look", style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (!wide) TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
          ],
        ),
        if (wide)
          for (final (label, on) in [("Instagram Reel", formats.contains("Reel")), ("TikTok", false), ("Facebook Page", false), ("Storefront look", storefront)])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label),
              value: label == "Storefront look" ? storefront : on,
              onChanged: label == "Storefront look"
                  ? onStorefront
                  : (value) {
                      if (label == "Instagram Reel") onFormat("Reel");
                      if (!value || label != "Instagram Reel") {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auto-posting is not in this version. Scheduling saves a reminder.")));
                      }
                    },
            )
        else
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Add to storefront"),
            value: storefront,
            onChanged: onStorefront,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text("Share to ClosetIQ", style: TextStyle(fontWeight: FontWeight.w600))),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(appUrl.isEmpty ? "The ClosetIQ App Store link is added in account settings." : appUrl),
                ));
              },
              child: const Text("Get the app"),
            ),
          ],
        ),
        const Text("Requires a ClosetIQ subscription. ClosetIQ is the app for styling your own closet and sharing with that community."),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Amazon upload pack"),
          subtitle: amazonPack ? const Text("The export arrives in a later phase. The reminder still keeps your product list.") : null,
          value: amazonPack,
          onChanged: onAmazon,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: when,
          isExpanded: true,
          decoration: const InputDecoration(labelText: "When"),
          items: const [
            DropdownMenuItem(value: "Tonight 6:30 PM", child: Text("Tonight 6:30 PM (best time)")),
            DropdownMenuItem(value: "Tomorrow 9:00 AM", child: Text("Tomorrow 9:00 AM")),
          ],
          onChanged: (value) { if (value != null) onWhen(value); },
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: caption));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caption copied.")));
            }
          },
          child: Text(wide ? "Copy caption" : "More… (copy caption)"),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key("schedule-post"),
          onPressed: onSchedule,
          child: Text(wide ? "Schedule everywhere" : "Schedule · $when"),
        ),
        const SizedBox(height: 6),
        Text(
          "Saves a reminder only. The iOS app does not auto-post, and web auto-posting is a later phase.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
