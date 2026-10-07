import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/features/home/home_screen.dart';
import 'package:dahab_app/widgets/mock_flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_app.dart';

/// Everything still on mock data carries a red flag; live screens don't.
void main() {
  setUpAll(loadAppFonts);

  testWidgets('a mock screen shows the red strip, a live one does not', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lang = (await tester.runAsync(LangController.load))!;
    await tester.pumpWidget((await tester.runAsync(() => testApp(lang)))!);
    await tester.pump(const Duration(milliseconds: 300));

    void go(String loc) => GoRouter.of(tester.element(find.byType(Navigator).first)).go(loc);

    // Backend spec 017: Help keeps its FAQ on mock data until the App text (spec 019).
    go('/help');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockScreenBanner), findsOneWidget);
    expect(find.text('MOCK — this screen is not connected to the backend yet'), findsOneWidget);

    // Backend spec 017: saved pieces are live.
    go('/saved');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockScreenBanner), findsNothing);

    // Backend spec 016: the invoices are live.
    go('/invoices');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockScreenBanner), findsNothing);

    go('/orders');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockScreenBanner), findsNothing);

    // Home: since backend spec 015 the gold prices and the calculator are live; since spec 017 the inbox bell too.
    go('/home');
    await tester.pump(const Duration(seconds: 1));
    expect(find.descendant(of: find.byType(MockMark), matching: find.byType(RateBar)), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
