import "package:closetiq_studio/app_state.dart";
import "package:closetiq_studio/config.dart";
import "package:closetiq_studio/main.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_fonts/google_fonts.dart";

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets("example studio walks create, storefront, and account deletion", (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ClosetIQStudioApp(state: AppState(config: AppConfig.preview())));
    await tester.pumpAndSettle();

    expect(find.text("Hi, Heather"), findsOneWidget);
    expect(find.text("What are we posting today?"), findsOneWidget);

    await tester.tap(find.byKey(const Key("nav-closet")));
    await tester.pumpAndSettle();
    expect(find.text("Gold drop earrings"), findsOneWidget);

    await tester.tap(find.byKey(const Key("nav-create")));
    await tester.pumpAndSettle();
    expect(find.text("What's the look?"), findsOneWidget);
    expect(find.text("Pick from my closet"), findsOneWidget);
    await tester.enterText(find.byKey(const Key("idea-field")), "Espresso season");
    await tester.tap(find.byKey(const Key("idea-continue")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Satin trousers"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("pieces-continue")));
    await tester.pumpAndSettle();
    expect(find.text("Try it on"), findsWidgets);
    await tester.tap(find.byKey(const Key("try-continue")));
    await tester.pumpAndSettle();
    expect(find.text("Make & share"), findsOneWidget);

    await tester.tap(find.byKey(const Key("open-share-sheet")));
    await tester.pumpAndSettle();
    expect(find.text("Share to ClosetIQ"), findsOneWidget);
    expect(find.text("Requires a ClosetIQ subscription. ClosetIQ is the app for styling your own closet and sharing with that community."), findsOneWidget);
    await tester.tap(find.byKey(const Key("schedule-post")));
    await tester.pumpAndSettle();
    expect(find.text("Espresso season"), findsWidgets);

    await tester.tap(find.byKey(const Key("nav-storefront")));
    await tester.pumpAndSettle();
    expect(find.text("closetiq.app/@heather"), findsOneWidget);
    await tester.tap(find.byKey(const Key("copy-storefront")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("storefront-qr")));
    await tester.pumpAndSettle();
    expect(find.text("Storefront QR"), findsOneWidget);
    await tester.tap(find.text("Close"));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("nav-home")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("open-insights")));
    await tester.pumpAndSettle();
    expect(find.text("Insights"), findsOneWidget);

    await tester.tap(find.byKey(const Key("nav-home")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("open-account")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("delete-account")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, "DELETE");
    await tester.tap(find.byKey(const Key("confirm-delete")));
    await tester.pumpAndSettle();
    expect(find.text("Preview with example content"), findsOneWidget);
    expect(find.text("Continue with Google"), findsOneWidget);
    expect(find.text("Sign in with Apple"), findsOneWidget);
  });
}
