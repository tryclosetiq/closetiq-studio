import "dart:async";
import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "config.dart";
import "data/demo_studio.dart";
import "data/studio_store.dart";
import "data/supabase_store.dart";
import "domain/product_meta.dart";
import "router.dart";

enum Gate { loading, signedOut, onboarding, ready }

class AppState extends ChangeNotifier {
  AppState({required this.config, this.client}) {
    router = buildRouter(this);
    if (config.startInPreview) {
      enterPreview();
    } else if (client == null) {
      gate = Gate.signedOut;
    } else {
      unawaited(_boot());
    }
  }

  final AppConfig config;
  final SupabaseClient? client;
  late final GoRouter router;

  Gate gate = Gate.loading;
  bool preview = false;
  StudioStore? store;
  String? banner;
  StreamSubscription<AuthState>? _authSub;

  bool get signedIn => gate == Gate.ready || gate == Gate.onboarding;

  void enterPreview() {
    preview = true;
    store = DemoStore(DemoStudio.heather());
    gate = Gate.ready;
    banner = null;
    notifyListeners();
  }

  void leavePreview() {
    preview = false;
    store = null;
    gate = Gate.signedOut;
    banner = null;
    notifyListeners();
  }

  Future<void> _boot() async {
    final supabase = client;
    if (supabase == null) return;
    _authSub = supabase.auth.onAuthStateChange.listen((event) {
      if (event.session == null && !preview) {
        store = null;
        gate = Gate.signedOut;
        notifyListeners();
      } else if (event.session != null && gate == Gate.signedOut) {
        unawaited(openStudio());
      }
    });
    if (supabase.auth.currentSession != null) {
      await openStudio();
    } else {
      gate = Gate.signedOut;
      notifyListeners();
    }
  }

  Future<void> openStudio() async {
    final supabase = client;
    if (supabase == null) return;
    preview = false;
    final remote = SupabaseStore(supabase);
    try {
      await remote.reload();
    } catch (error) {
      banner = "$error";
      gate = Gate.signedOut;
      notifyListeners();
      return;
    }
    store = remote;
    gate = remote.snapshot.settings.onboardingComplete ? Gate.ready : Gate.onboarding;
    banner = null;
    notifyListeners();
  }

  Future<String?> signIn(String email, String password) async {
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      final response = await supabase.auth.signInWithPassword(email: email.trim(), password: password);
      if (response.session == null) return "Check your email to confirm the account, then sign in.";
      await openStudio();
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {"full_name": name.trim()},
      );
      if (response.session == null) {
        return "Account created. Check your email to confirm it, then sign in.";
      }
      await openStudio();
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  Future<String?> resetPassword(String email) async {
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      await supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: config.authRedirect.isEmpty ? null : config.authRedirect,
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  Future<String?> updatePassword(String password) async {
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      await supabase.auth.updateUser(UserAttributes(password: password));
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  Future<String?> signInWithGoogle() => _oauth(OAuthProvider.google);

  Future<String?> signInWithApple() async {
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final rawNonce = _nonce();
        final hashed = sha256.convert(utf8.encode(rawNonce)).toString();
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
          nonce: hashed,
        );
        final token = credential.identityToken;
        if (token == null) return "Apple did not return a sign-in token.";
        await supabase.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: token, nonce: rawNonce);
        await openStudio();
        return null;
      }
      return await _oauth(OAuthProvider.apple);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      return error.message;
    } on AuthException catch (error) {
      return error.message;
    } catch (error) {
      return "$error";
    }
  }

  Future<String?> _oauth(OAuthProvider provider) async {
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      final launched = await supabase.auth.signInWithOAuth(
        provider,
        redirectTo: config.authRedirect.isEmpty ? null : config.authRedirect,
      );
      if (!launched) return "The sign-in window did not open.";
      if (supabase.auth.currentSession != null) await openStudio();
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  Future<void> signOut() async {
    if (preview) {
      leavePreview();
      return;
    }
    await client?.auth.signOut();
    store = null;
    gate = Gate.signedOut;
    notifyListeners();
  }

  Future<String?> deleteAccount() async {
    if (preview) {
      leavePreview();
      return null;
    }
    final supabase = client;
    if (supabase == null) return _missingBackend;
    try {
      await supabase.rpc("delete_own_account");
      await supabase.auth.signOut();
      store = null;
      gate = Gate.signedOut;
      banner = "Your account was deleted.";
      notifyListeners();
      return null;
    } on PostgrestException catch (error) {
      return error.message;
    }
  }

  Future<ImportResult> importUrl(String url) async {
    final current = store;
    if (current is SupabaseStore) return current.importUrl(url);
    return const ProductImporter().import(url);
  }

  Future<void> refresh() async {
    await store?.reload();
    if (store != null && gate == Gate.onboarding && store!.snapshot.settings.onboardingComplete) {
      gate = Gate.ready;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    router.dispose();
    super.dispose();
  }

  static const _missingBackend = "Add SUPABASE_URL and SUPABASE_ANON_KEY for a new Supabase project before creating an account.";
}

String _nonce([int length = 32]) {
  const chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._";
  final random = Random.secure();
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

class StudioScope extends InheritedNotifier<AppState> {
  const StudioScope({required AppState state, required super.child, super.key}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StudioScope>();
    assert(scope != null, "StudioScope missing");
    return scope!.notifier!;
  }
}
