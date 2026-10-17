import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "app_state.dart";
import "config.dart";
import "theme/brand.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  SupabaseClient? client;
  if (config.hasBackend) {
    await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabaseAnonKey);
    client = Supabase.instance.client;
  }
  runApp(ClosetIQStudioApp(state: AppState(config: config, client: client)));
}

class ClosetIQStudioApp extends StatelessWidget {
  const ClosetIQStudioApp({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return StudioScope(
      state: state,
      child: MaterialApp.router(
        title: "ClosetIQ Studio",
        debugShowCheckedModeBanner: false,
        theme: buildStudioTheme(),
        routerConfig: state.router,
      ),
    );
  }
}
