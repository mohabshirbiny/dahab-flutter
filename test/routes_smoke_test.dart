import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_app.dart';

/// Every route plus the query-driven variants.
List<String> get _locations => [
  for (final id in allScreenIds) '/$id',
  for (final v in ['owner', 'cancelled', 'requested', 'accepted']) '/detail?view=$v',
  '/detail?id=p4',
  '/txn?id=t2',
];

/// Renders every screen at small-phone, phone, tablet and desktop sizes in
/// both languages. Any overflow or exception fails the test.
void main() {
  setUpAll(loadAppFonts);

  for (final lang in AppLang.values) {
    for (final size in const [Size(320, 640), Size(375, 812), Size(768, 1024), Size(1280, 800)]) {
      testWidgets('all routes render cleanly — ${lang.name} ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final controller = (await tester.runAsync(LangController.load))!;
        controller.setLang(lang);
        await tester.pumpWidget((await tester.runAsync(() => testApp(controller)))!);
        await tester.pump(const Duration(milliseconds: 500));

        final failures = <String>[];
        for (final loc in _locations) {
          GoRouter.of(tester.element(find.byType(Navigator).first)).go(loc);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          final e = tester.takeException();
          if (e != null) failures.add('$loc: $e');
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        expect(failures, isEmpty, reason: failures.join('\n\n'));
      });
    }
  }
}
