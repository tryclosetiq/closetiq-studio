import "package:closetiq_studio/app_state.dart";
import "package:closetiq_studio/config.dart";
import "package:closetiq_studio/main.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:google_fonts/google_fonts.dart";

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets("example studio walks the live Studio tabs", (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(ClosetIQStudioApp(state: AppState(config: AppConfig.preview())));
    await tester.pumpAndSettle();

    expect(find.text("ClosetIQ Studio"), findsOneWidget);
    expect(find.text("My Models"), findsOneWidget);
    expect(find.textContaining("today"), findsOneWidget);
    expect(find.textContaining("left"), findsOneWidget);

    final pageScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const Key("open-generate-model")), 250, scrollable: pageScroll);
    await tester.tap(find.byKey(const Key("open-generate-model")));
    await tester.pumpAndSettle();
    expect(find.text("Generate a model"), findsOneWidget);
    expect(find.text("Studio neutral"), findsWidgets);
    expect(find.text("Fast · 1 credit"), findsOneWidget);
    expect(find.text("Balanced · 2 credits"), findsOneWidget);
    expect(find.text("1 credit for one image."), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("Generate"),
      200,
      scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.text("Generate"));
    await tester.pump();
    expect(find.textContaining("nothing is charged"), findsOneWidget);
    await closeSheet(tester, "Generate a model");

    await openTab(tester, "nav-clothing");
    expect(find.text("My Clothing"), findsOneWidget);
    expect(find.text("Gold drop earrings"), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key("add-item")), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key("add-item")));
    await tester.pumpAndSettle();
    expect(find.text("Product URL"), findsOneWidget);
    await tester.tap(find.text("Import from URL"));
    await tester.pump();
    expect(find.textContaining("Add the photo, name and price yourself"), findsWidgets);
    await closeSheet(tester, "Add an item");

    await openTab(tester, "nav-storefront");
    expect(find.text("closetiq.app/@heather"), findsOneWidget);
    await tester.tap(find.byKey(const Key("copy-storefront")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Link copied."), findsOneWidget);
    await clearSnacks(tester);
    await tester.tap(find.byKey(const Key("storefront-qr")));
    await tester.pumpAndSettle();
    expect(find.text("Storefront QR"), findsOneWidget);
    await tester.tap(find.text("Close"));
    await tester.pumpAndSettle();

    await openTab(tester, "nav-outfits");
    await tester.scrollUntilVisible(find.byKey(const Key("open-share-sheet")), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key("open-share-sheet")));
    await tester.pumpAndSettle();
    expect(find.text("Share to ClosetIQ"), findsOneWidget);
    expect(find.text("Requires a ClosetIQ subscription. ClosetIQ is the app for styling your own closet and sharing with that community."), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key("schedule-post")),
      200,
      scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.byKey(const Key("schedule-post")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Spotted in Espresso"), findsWidgets);
    await clearSnacks(tester);

    await tester.tap(find.byKey(const Key("open-account")));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key("delete-account")));
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

Future<void> clearSnacks(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> closeSheet(WidgetTester tester, String title) async {
  Navigator.of(tester.element(find.text(title))).pop();
  await tester.pumpAndSettle();
  await clearSnacks(tester);
}

Future<void> openTab(WidgetTester tester, String key) async {
  await clearSnacks(tester);
  final tabScroll = find.descendant(of: find.byKey(const Key("studio-tabs")), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.byKey(Key(key)), 80, scrollable: tabScroll);
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}
