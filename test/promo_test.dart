import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_app.dart';

// Backend spec 023: Invite a friend, against the fake backend.

Future<FakeBackend> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeBackend();
  final lang = (await tester.runAsync(LangController.load))!;
  await tester.pumpWidget((await tester.runAsync(() => testApp(lang, backend: api)))!);
  await tester.pump(const Duration(milliseconds: 300));
  return api;
}

Future<void> _settle(WidgetTester tester, [int ms = 1000]) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final all = find.text(text);
  expect(all, findsWidgets, reason: 'no "$text" on screen');
  await tester.ensureVisible(all.last);
  await tester.pump();
  await tester.tap(all.last);
  await _settle(tester);
}

Finder _field(String label) => find.descendant(of: find.widgetWithText(DField, label), matching: find.byType(TextField)).last;

void _go(WidgetTester tester, String loc) => GoRouter.of(tester.element(find.byType(Navigator).first)).go(loc);

Future<void> _signIn(WidgetTester tester) async {
  await _tap(tester, 'I already have one');
  await tester.enterText(_field('Phone number'), '010 1234 4417');
  await tester.enterText(_field('Password'), 'Password-1234');
  await _tap(tester, 'Sign in');
  final boxes = find.descendant(of: find.byType(DOtp), matching: find.byType(TextField));
  for (var i = 0; i < 6; i++) {
    await tester.enterText(boxes.at(i), '123456'[i]);
  }
  await tester.pump();
  await _tap(tester, 'Verify');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Invite a friend shows the code and the live terms, and a share is counted', (tester) async {
    final api = await _start(tester);
    await _signIn(tester);
    _go(tester, '/invite');
    await _settle(tester);

    expect(find.text('REF-TEST01'), findsOneWidget);
    expect(find.textContaining('50% less commission'), findsOneWidget);
    expect(find.textContaining('100 EGP'), findsOneWidget);
    expect(find.text('Invites sent'), findsOneWidget);

    await _tap(tester, 'Copy');
    expect(api.requests.where((r) => r.url.path == '/api/v1/customer/me/referral/shares'), isNotEmpty);
    final share = api.requests.where((r) => r.url.path.endsWith('/referral/shares')).last;
    expect(share.headers['Idempotency-Key'], isNotEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
