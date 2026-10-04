import 'package:dahab_app/core/i18n/i18n.dart';
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

    go('/invoices');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockScreenBanner), findsOneWidget);
    expect(find.text('MOCK — this screen is not connected to the backend yet'), findsOneWidget);

    go('/orders');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockScreenBanner), findsNothing);

    // Home: the gold feed, the calculator and the inbox bell are mock.
    go('/home');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MockFlag), findsAtLeastNWidgets(3));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
