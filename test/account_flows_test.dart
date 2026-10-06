import 'dart:convert';

import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'test_app.dart';

// Backend spec 017: the account screens against the fake backend.

Future<FakeBackend> _acStart(WidgetTester tester, {FakeBackend? backend}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = backend ?? FakeBackend();
  final lang = (await tester.runAsync(LangController.load))!;
  await tester.pumpWidget((await tester.runAsync(() => testApp(lang, backend: api)))!);
  await tester.pump(const Duration(milliseconds: 300));
  return api;
}

Future<void> _acSettle(WidgetTester tester, [int ms = 1000]) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
}

Future<void> _acTap(WidgetTester tester, String text) async {
  final all = find.text(text);
  expect(all, findsWidgets, reason: 'no "$text" on screen');
  await tester.ensureVisible(all.last);
  await tester.pump();
  await tester.tap(all.last);
  await _acSettle(tester);
}

Finder _acField(String label) => find.descendant(of: find.widgetWithText(DField, label), matching: find.byType(TextField)).last;

void _acGo(WidgetTester tester, String loc) => GoRouter.of(tester.element(find.byType(Navigator).first)).go(loc);

/// Sign in through the login screen and the new-device code.
Future<void> _acSignIn(WidgetTester tester) async {
  await _acTap(tester, 'I already have one');
  await tester.enterText(_acField('Phone number'), '010 1234 4417');
  await tester.enterText(_acField('Password'), 'Password-1234');
  await _acTap(tester, 'Sign in');
  final boxes = find.descendant(of: find.byType(DOtp), matching: find.byType(TextField));
  for (var i = 0; i < 6; i++) {
    await tester.enterText(boxes.at(i), '123456'[i]);
  }
  await tester.pump();
  await _acTap(tester, 'Verify');
}

Future<void> _acEnd(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('change the phone number with the code sent to it', (tester) async {
    final api = await _acStart(tester);
    await _acSignIn(tester);
    _acGo(tester, '/change-phone');
    await _acSettle(tester);

    await tester.enterText(_acField('New phone number'), '010 9999 9999');
    await _acTap(tester, 'Send the code');
    expect(find.text('This number or address is already used by another account.'), findsOneWidget);

    await tester.enterText(_acField('New phone number'), '010 1111 2222');
    await _acTap(tester, 'Send the code');
    expect(find.textContaining('+20 10 •••• 2222'), findsOneWidget);

    await tester.enterText(_acField('Code'), '000000');
    await _acTap(tester, 'Change my number');
    expect(find.text('That code is not right or has expired.'), findsOneWidget);

    await tester.enterText(_acField('Code'), FakeBackend.phoneCode);
    await _acTap(tester, 'Change my number');
    expect(find.text('Your number is changed'), findsOneWidget);

    final sent = api.requests.where((r) => r.url.path.endsWith('/phone-change')).last;
    expect(jsonDecode(sent.body)['phone'], '+201011112222');
    expect(sent.headers['Idempotency-Key'], isNotEmpty);
    await _acEnd(tester);
  });

  testWidgets('change the email: the link goes to the new address, the page confirms it', (tester) async {
    await _acStart(tester);
    await _acSignIn(tester);
    _acGo(tester, '/change-email');
    await _acSettle(tester);
    await tester.enterText(_acField('New email address'), 'new@example.com');
    await _acTap(tester, 'Send the link');
    expect(find.textContaining('n•••@example.com'), findsOneWidget);

    _acGo(tester, '/email-confirm?token=${FakeBackend.emailToken}');
    await _acSettle(tester);
    await _acTap(tester, 'Confirm this email');
    expect(find.textContaining('Your email is now'), findsOneWidget);

    _acGo(tester, '/email-confirm?token=not-the-right-token-at-all');
    await _acSettle(tester);
    expect(find.text('This link has expired'), findsOneWidget);
    await _acEnd(tester);
  });

  testWidgets('change the password and sign another device out', (tester) async {
    final api = await _acStart(tester);
    await _acSignIn(tester);
    _acGo(tester, '/security');
    await _acSettle(tester);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('iPhone or iPad'), findsOneWidget);

    await tester.enterText(_acField('Current password'), 'wrong-password');
    await tester.enterText(_acField('New password'), 'a-brand-new-one-9');
    await _acTap(tester, 'Change password');
    expect(find.text('Your current password is not right.'), findsOneWidget);

    await tester.enterText(_acField('Current password'), 'Password123!');
    await tester.enterText(_acField('New password'), 'a-brand-new-one-9');
    await _acTap(tester, 'Change password');
    expect(api.requests.where((r) => r.url.path.endsWith('/customer/me/password')), hasLength(2));

    await _acTap(tester, 'Sign out');
    await _acTap(tester, 'Sign out');
    expect(api.sessions, hasLength(1));
    expect(find.text('iPhone or iPad'), findsNothing);
    await _acEnd(tester);
  });

  testWidgets('the inbox shows what was sent, marks it read and the bell counts it', (tester) async {
    final api = FakeBackend()
      ..inbox = [
        {
          'id': '1a000000-0000-4000-8000-000000000001',
          'type': 'order.paid',
          'link': {'kind': 'order', 'id': null},
          'title_en': 'Paid in full',
          'title_ar': 'اتدفع بالكامل',
          'body_en': 'Your collection code is ••••••.',
          'body_ar': 'كود الاستلام ••••••.',
          'created_at': '2026-10-06T09:00:00+03:00',
          'read_at': null,
        },
      ];
    await _acStart(tester, backend: api);
    await _acSignIn(tester);
    _acGo(tester, '/inbox');
    await _acSettle(tester);
    expect(find.text('Paid in full'), findsOneWidget);

    await _acTap(tester, 'Mark all as read');
    expect(api.inbox.every((n) => n['read_at'] != null), isTrue);
    expect(find.text('Mark all as read'), findsNothing);
    await _acEnd(tester);
  });

  testWidgets('saved pieces: a piece that left the market can be removed', (tester) async {
    final api = FakeBackend()..saved.add('5a000000-0000-4000-8000-000000000001');
    await _acStart(tester, backend: api);
    await _acSignIn(tester);
    _acGo(tester, '/saved');
    await _acSettle(tester);
    expect(find.text('No longer available'), findsOneWidget);
    await _acTap(tester, 'Remove');
    expect(api.saved, isEmpty);
    expect(find.text('Nothing here yet'), findsOneWidget);
    await _acEnd(tester);
  });

  testWidgets('report a listing with a reason and a note', (tester) async {
    final api = await _acStart(tester);
    await _acSignIn(tester);
    _acGo(tester, '/report?id=5a000000-0000-4000-8000-000000000001&title=Ring');
    await _acSettle(tester);
    await _acTap(tester, 'Send report');
    expect(find.text('Choose what looks wrong first.'), findsOneWidget);

    await _acTap(tester, 'The price or the weight looks wrong');
    await tester.enterText(find.byType(TextField).last, 'Too light for the photos');
    await _acTap(tester, 'Send report');
    expect(api.reports.single['reason'], 'price_or_weight_wrong');
    expect(api.reports.single['note'], 'Too light for the photos');
    await _acEnd(tester);
  });

  testWidgets('closing is refused while money is left, then closes and signs out', (tester) async {
    final api = FakeBackend()
      ..closeBlockers = [
        {'code': 'wallet_balance', 'count': 1},
      ];
    await _acStart(tester, backend: api);
    await _acSignIn(tester);
    _acGo(tester, '/delete');
    await _acSettle(tester);
    expect(find.text('You have things in progress'), findsOneWidget);
    expect(find.text('Money in your wallet'), findsOneWidget);

    api.closeBlockers = [];
    _acGo(tester, '/account');
    await _acSettle(tester);
    _acGo(tester, '/delete');
    await _acSettle(tester);
    await _acTap(tester, 'Fees are too high');
    await _acTap(tester, 'Close my account');
    await _acTap(tester, 'Close my account');
    expect(api.closed, isTrue);
    await _acEnd(tester);
  });

  testWidgets('terms, privacy and contact come from the backend', (tester) async {
    await _acStart(tester);
    _acGo(tester, '/legal');
    await _acSettle(tester);
    expect(find.text('Not published yet'), findsNWidgets(3));
    await _acTap(tester, 'Terms of use');
    expect(find.text('These are the terms of use.'), findsOneWidget);

    _acGo(tester, '/support');
    await _acSettle(tester);
    expect(find.text('16000'), findsOneWidget);
    expect(find.text('help@dahabapp.com'), findsOneWidget);
    await _acEnd(tester);
  });
}
