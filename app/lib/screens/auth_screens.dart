import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_state.dart";
import "../theme/brand.dart";

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() { _busy = true; _message = null; });
    final message = await action();
    if (!mounted) return;
    setState(() { _busy = false; _message = message; });
  }

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("CLOSETIQ STUDIO", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Brand.gold, letterSpacing: 1.4)),
                  const SizedBox(height: 8),
                  Text("Sign in", style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  const Text("The creator tool for shoppable try-on content, Reels, and a storefront that earns commissions."),
                  const SizedBox(height: 20),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: "Email")),
                  const SizedBox(height: 10),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(() => state.signIn(_email.text, _password.text)),
                    child: Text(_busy ? "Signing in…" : "Sign in"),
                  ),
                  const SizedBox(height: 10),
                  const _SocialButtons(),
                  TextButton(onPressed: () => context.go("/reset"), child: const Text("Forgot password")),
                  TextButton(onPressed: () => context.go("/sign-up"), child: const Text("Create an account")),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key("preview-studio"),
                    onPressed: state.enterPreview,
                    child: const Text("Preview with example content"),
                  ),
                  if (state.banner != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(state.banner!, style: const TextStyle(color: Brand.positive))),
                  if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, style: const TextStyle(color: Brand.danger))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_consent) {
      setState(() => _message = "Agree to the Terms and Privacy Policy to create an account.");
      return;
    }
    if (_password.text.length < 12) {
      setState(() => _message = "Use at least 12 characters.");
      return;
    }
    setState(() { _busy = true; _message = null; });
    final message = await StudioScope.of(context).signUp(_name.text, _email.text, _password.text);
    if (!mounted) return;
    setState(() { _busy = false; _message = message; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Create your studio", style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 14),
                  const _Positioning(),
                  const SizedBox(height: 18),
                  TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: "Your name")),
                  const SizedBox(height: 10),
                  TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(labelText: "Email")),
                  const SizedBox(height: 10),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "Password (12+ characters)")),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consent,
                    onChanged: (value) => setState(() => _consent = value ?? false),
                    title: const Text("I agree to the Terms of Use and Privacy Policy. Those pages are linked before the public launch."),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? "Creating…" : "Create account")),
                  const SizedBox(height: 10),
                  const _SocialButtons(),
                  TextButton(onPressed: () => context.go("/sign-in"), child: const Text("I already have an account")),
                  if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text("Reset password", style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                const Text("We'll email you a link. After you open it, set a new password here."),
                const SizedBox(height: 16),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    final message = await state.resetPassword(_email.text);
                    if (!mounted) return;
                    setState(() {
                      _sent = message == null;
                      _message = message ?? "Reset email sent, if an account exists for that address.";
                    });
                  },
                  child: const Text("Email me a reset link"),
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "New password (12+ characters)")),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      if (_password.text.length < 12) {
                        setState(() => _message = "Use at least 12 characters.");
                        return;
                      }
                      final message = await state.updatePassword(_password.text);
                      if (!mounted) return;
                      setState(() => _message = message ?? "Password updated. Sign in with it.");
                    },
                    child: const Text("Save new password"),
                  ),
                ],
                TextButton(onPressed: () => context.go("/sign-in"), child: const Text("Back to sign in")),
                if (_message != null) Text(_message!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    final state = StudioScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final message = await state.signInWithGoogle();
            if (message != null && context.mounted) _toast(context, message);
          },
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text("Continue with Google"),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
          onPressed: () async {
            final message = await state.signInWithApple();
            if (message != null && context.mounted) _toast(context, message);
          },
          child: const Text("Sign in with Apple"),
        ),
      ],
    );
  }
}

class _Positioning extends StatelessWidget {
  const _Positioning();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _ProductCard(
          title: "ClosetIQ",
          body: "The app for styling your own closet, building collages, getting them rated, and sharing with the ClosetIQ community.",
        )),
        SizedBox(width: 10),
        Expanded(child: _ProductCard(
          title: "ClosetIQ Studio",
          body: "The creator tool for making shoppable try-on content, Reels, and a storefront that earns you commissions.",
        )),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: studioCard(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
