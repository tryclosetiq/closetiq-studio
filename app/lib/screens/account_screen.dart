import "package:flutter/material.dart";

import "../app_state.dart";
import "../domain/handle_rules.dart";
import "../theme/brand.dart";

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _tag = TextEditingController();
  final _disclosure = TextEditingController();
  final _password = TextEditingController();
  var _seeded = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final settings = StudioScope.of(context).store?.snapshot.settings;
    if (settings == null) return;
    _name.text = settings.displayName;
    _handle.text = settings.handle ?? "";
    _tag.text = settings.amazonTag ?? "";
    _disclosure.text = settings.disclosure;
    _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _tag.dispose();
    _disclosure.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    final settings = state.store?.snapshot.settings;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("Account", style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 6),
          Text(settings?.email ?? "", style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: "Name")),
          const SizedBox(height: 8),
          TextField(controller: _handle, decoration: const InputDecoration(labelText: "Storefront handle", prefixText: "@"), autocorrect: false),
          const SizedBox(height: 8),
          TextField(controller: _tag, decoration: const InputDecoration(labelText: "Amazon Associates tag"), autocorrect: false),
          const SizedBox(height: 8),
          TextField(controller: _disclosure, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: "Affiliate disclosure")),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final error = handleError(_handle.text);
              if (error != null) {
                setState(() => _message = error);
                return;
              }
              try {
                await state.store!.saveSettings(settings!.copyWith(
                  displayName: _name.text.trim(),
                  handle: normalizeHandle(_handle.text),
                  amazonTag: _tag.text.trim(),
                  disclosure: _disclosure.text.trim(),
                  clearTag: _tag.text.trim().isEmpty,
                ));
                await state.refresh();
                if (mounted) setState(() => _message = "Saved.");
              } catch (error) {
                if (mounted) setState(() => _message = "$error");
              }
            },
            child: const Text("Save"),
          ),
          const SizedBox(height: 20),
          Text("Password", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "New password (12+ characters)")),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              if (state.preview) {
                setState(() => _message = "Password changes need a connected account.");
                return;
              }
              final message = await state.updatePassword(_password.text);
              if (mounted) setState(() => _message = message ?? "Password updated.");
            },
            child: const Text("Change password"),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: state.signOut, child: Text(state.preview ? "Leave example studio" : "Sign out")),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key("delete-account"),
            style: FilledButton.styleFrom(backgroundColor: Brand.danger),
            onPressed: () => _confirmDelete(context),
            child: const Text("Delete account"),
          ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    final message = await StudioScope.of(context).deleteAccount();
    if (!context.mounted) return;
    if (message != null) setState(() => _message = message);
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Brand.cream,
      title: const Text("Delete your account?"),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("This permanently deletes your ClosetIQ Studio account, including your closet, looks, storefront, photos and settings. It cannot be undone."),
              const SizedBox(height: 8),
              const Text("Billing is not turned on in this version, so there is no subscription to cancel here."),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 1,
                decoration: const InputDecoration(labelText: "Type DELETE to confirm"),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        FilledButton(
          key: const Key("confirm-delete"),
          style: FilledButton.styleFrom(backgroundColor: Brand.danger),
          onPressed: () => Navigator.pop(context, _controller.text.trim() == "DELETE"),
          child: const Text("Delete account"),
        ),
      ],
    );
  }
}
