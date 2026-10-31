import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../domain/handle_rules.dart";
import "../theme/brand.dart";

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _handle = TextEditingController();
  final _tag = TextEditingController();
  final _disclosure = TextEditingController(text: "As an Amazon Associate I earn from qualifying purchases.");
  var _seeded = false;
  String? _message;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final settings = StudioScope.of(context).store?.snapshot.settings;
    if (settings == null) return;
    _handle.text = settings.handle ?? "";
    _tag.text = settings.amazonTag ?? "";
    _disclosure.text = settings.disclosure;
    _seeded = true;
  }

  @override
  void dispose() {
    _handle.dispose();
    _tag.dispose();
    _disclosure.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final error = handleError(_handle.text);
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    if (_disclosure.text.trim().isEmpty) {
      setState(() => _message = "Add the affiliate disclosure shoppers will see.");
      return;
    }
    final state = StudioScope.of(context);
    final current = state.store!.snapshot.settings;
    setState(() { _busy = true; _message = null; });
    try {
      await state.store!.saveSettings(current.copyWith(
        handle: normalizeHandle(_handle.text),
        amazonTag: _tag.text.trim(),
        disclosure: _disclosure.text.trim(),
        onboardingComplete: true,
        clearTag: _tag.text.trim().isEmpty,
      ));
      await state.refresh();
      if (mounted) context.go("/home");
    } catch (error) {
      if (mounted) setState(() => _message = "$error");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text("Set up your studio", style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                const Text("A short checklist. You can change any of this later in Settings."),
                const SizedBox(height: 18),
                const _Check(done: true, title: "Account created"),
                const SizedBox(height: 12),
                TextField(controller: _handle, decoration: const InputDecoration(labelText: "Storefront handle", prefixText: "@"), autocorrect: false),
                const SizedBox(height: 8),
                TextField(controller: _tag, decoration: const InputDecoration(labelText: "Amazon Associates tag (optional)"), autocorrect: false),
                const SizedBox(height: 8),
                TextField(controller: _disclosure, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: "Affiliate disclosure")),
                const SizedBox(height: 8),
                const _Check(done: false, title: "Add your first piece — optional, from Closet after this"),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _finish, child: Text(_busy ? "Saving…" : "Finish setup")),
                TextButton(onPressed: () => context.go("/account"), child: const Text("Account & delete")),
                if (_message != null) Text(_message!, style: const TextStyle(color: Brand.danger)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done, required this.title});

  final bool done;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? Brand.positive : Brand.muted, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ],
    );
  }
}
