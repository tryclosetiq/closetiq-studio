import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "app_state.dart";
import "screens/account_screen.dart";
import "screens/auth_screens.dart";
import "screens/closet_screen.dart";
import "screens/create_flow_screen.dart";
import "screens/home_screen.dart";
import "screens/insights_screen.dart";
import "screens/onboarding_screen.dart";
import "screens/schedule_screen.dart";
import "screens/storefront_screen.dart";
import "widgets/studio_shell.dart";

GoRouter buildRouter(AppState state) {
  return GoRouter(
    initialLocation: "/loading",
    refreshListenable: state,
    redirect: (context, route) {
      final loc = route.matchedLocation;
      final authRoute = loc == "/sign-in" || loc == "/sign-up" || loc == "/reset";
      switch (state.gate) {
        case Gate.loading:
          return loc == "/loading" ? null : "/loading";
        case Gate.signedOut:
          return authRoute ? null : "/sign-in";
        case Gate.onboarding:
          if (loc == "/onboarding" || loc == "/account") return null;
          return "/onboarding";
        case Gate.ready:
          if (loc == "/loading" || authRoute || loc == "/onboarding") return "/home";
          return null;
      }
    },
    routes: [
      GoRoute(path: "/loading", builder: (context, route) => const _LoadingScreen()),
      GoRoute(path: "/sign-in", builder: (context, route) => const SignInScreen()),
      GoRoute(path: "/sign-up", builder: (context, route) => const SignUpScreen()),
      GoRoute(path: "/reset", builder: (context, route) => const ResetPasswordScreen()),
      GoRoute(path: "/onboarding", builder: (context, route) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, route, child) => StudioShell(location: route.uri.path, child: child),
        routes: [
          GoRoute(path: "/home", builder: (context, route) => const HomeScreen()),
          GoRoute(path: "/closet", builder: (context, route) => const ClosetScreen()),
          GoRoute(path: "/create", builder: (context, route) => const CreateFlowScreen()),
          GoRoute(path: "/storefront", builder: (context, route) => const StorefrontScreen()),
          GoRoute(path: "/schedule", builder: (context, route) => const ScheduleScreen()),
          GoRoute(path: "/insights", builder: (context, route) => const InsightsScreen()),
          GoRoute(path: "/account", builder: (context, route) => const AccountScreen()),
        ],
      ),
    ],
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
