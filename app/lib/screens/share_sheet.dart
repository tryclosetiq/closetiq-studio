import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../app_state.dart";
import "../theme/brand.dart";

/// Share options for a look. Reachable from Outfits, Collages, Reels, and Try-On.
/// Scheduling saves a reminder only.
Future<void> showShareSheet(BuildContext context, {String? outfitId, String title = "New look", String caption = ""}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Brand.cream,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ShareSheet(outfitId: outfitId, title: title, caption: caption),
      ),
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.outfitId, required this.title, required this.caption});

  final String? outfitId;
  final String title;
  final String caption;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _storefront = true;
  bool _amazonPack = false;
  var _when = "Tonight 6:30 PM";
  bool _busy = false;

  Future<void> _schedule() async {
    final state = StudioScope.of(context);
    final store = state.store;
    if (store == null) return;
    setState(() => _busy = true);
    final when = _when.startsWith("Tomorrow")
        ? DateTime.now().add(const Duration(days: 1, hours: 9))
        : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 18, 30);
    final at = when.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(hours: 2)) : when;
    try {
      var outfitId = widget.outfitId;
      if (outfitId == null) {
        outfitId = await store.createLook(name: widget.title, idea: widget.title, itemIds: const [], caption: widget.caption, published: _storefront);
      } else if (_storefront) {
        await store.setPublished(outfitId, true);
      }
      await store.schedule(
        title: widget.title,
        when: at,
        caption: widget.caption,
        networks: [if (_storefront) "storefront"],
        outfitId: outfitId,
      );
      await state.refresh();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder saved. Nothing is auto-posted.")));
    } catch (error) {
      if (mounted) setState(() { _busy = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final appUrl = state.store?.snapshot.settings.appStoreUrl ?? state.config.closetIqAppStoreUrl;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Share this look", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(widget.title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Add to storefront"),
            value: _storefront,
            activeThumbColor: Brand.gold,
            onChanged: (value) => setState(() => _storefront = value),
          ),
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
            subtitle: _amazonPack ? const Text("The export arrives in a later phase. The reminder still keeps your product list.") : null,
            value: _amazonPack,
            activeThumbColor: Brand.gold,
            onChanged: (value) => setState(() => _amazonPack = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: _when,
            isExpanded: true,
            decoration: const InputDecoration(labelText: "When"),
            items: const [
              DropdownMenuItem(value: "Tonight 6:30 PM", child: Text("Tonight 6:30 PM (best time)")),
              DropdownMenuItem(value: "Tomorrow 9:00 AM", child: Text("Tomorrow 9:00 AM")),
            ],
            onChanged: (value) { if (value != null) setState(() => _when = value); },
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.caption.isEmpty ? widget.title : widget.caption));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Caption copied.")));
              }
            },
            child: const Text("More… (copy caption)"),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key("schedule-post"),
            onPressed: _busy ? null : _schedule,
            child: Text(_busy ? "Saving…" : "Schedule · $_when"),
          ),
          const SizedBox(height: 6),
          Text(
            "Saves a reminder only. The app does not auto-post.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
