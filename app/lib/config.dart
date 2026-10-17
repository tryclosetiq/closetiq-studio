/// Public configuration. Secrets are passed at build time and are never stored
/// in the repo. An empty URL keeps the app in preview / sign-in only.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.storefrontOrigin,
    required this.authRedirect,
    required this.closetIqAppStoreUrl,
    required this.startInPreview,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String storefrontOrigin;
  final String authRedirect;
  final String closetIqAppStoreUrl;
  final bool startInPreview;

  bool get hasBackend {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    return url.startsWith("https://") &&
        !url.contains("YOUR_PROJECT") &&
        key.isNotEmpty &&
        !key.contains("YOUR_ANON") &&
        !key.contains("YOUR_KEY");
  }

  String storefrontUrl(String handle) {
    final origin = storefrontOrigin.replaceAll(RegExp(r"/+$"), "");
    return "$origin/@$handle";
  }

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      supabaseUrl: const String.fromEnvironment("SUPABASE_URL"),
      supabaseAnonKey: const String.fromEnvironment("SUPABASE_ANON_KEY"),
      storefrontOrigin: const String.fromEnvironment(
        "STOREFRONT_ORIGIN",
        defaultValue: "https://closetiq.app",
      ),
      authRedirect: const String.fromEnvironment("AUTH_REDIRECT"),
      closetIqAppStoreUrl: const String.fromEnvironment("CLOSETIQ_APP_STORE_URL"),
      startInPreview: const bool.fromEnvironment("STUDIO_PREVIEW"),
    );
  }

  factory AppConfig.preview() {
    return const AppConfig(
      supabaseUrl: "",
      supabaseAnonKey: "",
      storefrontOrigin: "https://closetiq.app",
      authRedirect: "",
      closetIqAppStoreUrl: "",
      startInPreview: true,
    );
  }
}
