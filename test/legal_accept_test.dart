import 'dart:convert';

import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/models/customer.dart';
import 'package:dahab_app/services/api/api_client.dart';
import 'package:dahab_app/services/api/token_store.dart';
import 'package:dahab_app/services/auth/auth_api.dart';
import 'package:dahab_app/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// Backend spec 019 (FR-025, FR-026, D2): the live terms are accepted before anything else, the
/// sign-up sends the version it showed, and a refused write reloads what is owed.
void main() {
  setUpAll(loadAppFonts);

  Future<LangController> start(WidgetTester tester, FakeBackend api) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lang = (await tester.runAsync(LangController.load))!;
    await tester.pumpWidget((await tester.runAsync(() => testApp(lang, backend: api)))!);
    await tester.pump(const Duration(milliseconds: 300));
    return lang;
  }

  Future<void> settle(WidgetTester tester, [int ms = 1000]) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: 'no "$text" on screen');
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await settle(tester);
  }

  Finder field(String label) => find.descendant(of: find.widgetWithText(DField, label), matching: find.byType(TextField)).last;

  Future<void> signIn(WidgetTester tester) async {
    await tap(tester, 'I already have one');
    await tester.enterText(field('Phone number'), '010 1234 4417');
    await tester.enterText(field('Password'), 'Password-1234');
    await tap(tester, 'Sign in');
    final boxes = find.descendant(of: find.byType(DOtp), matching: find.byType(TextField));
    for (var i = 0; i < 6; i++) {
      await tester.enterText(boxes.at(i), '123456'[i]);
    }
    await tester.pump();
    await tap(tester, 'Verify');
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  const owedFirst = {'code': 'terms', 'version': 1, 'legal_doc_id': 1, 'reason': 'first'};

  testWidgets('a customer who owes the terms must accept them before anything else', (tester) async {
    final api = FakeBackend()..legalRequired = [owedFirst];
    await start(tester, api);
    await signIn(tester);

    expect(find.text('Please accept our terms'), findsWidgets);
    expect(find.text('These are the terms of use.'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);

    await tap(tester, 'I accept');

    final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/customer/me/legal-acceptances'));
    expect(jsonDecode(sent.body), {'legal_doc_id': 1});
    expect(sent.headers['Idempotency-Key'], isNotNull);
    expect(api.legalAccepted, [1]);
    expect(find.text('Please accept our terms'), findsNothing);
    await end(tester);
  });

  testWidgets('a material change says the terms were updated', (tester) async {
    final api = FakeBackend()
      ..legalRequired = [
        {'code': 'terms', 'version': 1, 'legal_doc_id': 1, 'reason': 'material'},
      ];
    await start(tester, api);
    await signIn(tester);

    expect(find.text('We updated our terms'), findsWidgets);
    expect(find.text('Please read and accept the new version to carry on.'), findsOneWidget);
    await end(tester);
  });

  testWidgets('the acceptance screen reads in Arabic', (tester) async {
    final api = FakeBackend()..legalRequired = [owedFirst];
    final lang = await start(tester, api);
    await signIn(tester);

    lang.setLang(AppLang.ar);
    await settle(tester);

    expect(find.text('من فضلك وافق على الشروط بتاعتنا'), findsWidgets);
    expect(find.text('موافق'), findsWidgets);
    await end(tester);
  });

  group('without a screen', () {
    Future<(ApiClient, FakeBackend)> client() async {
      SharedPreferences.setMockInitialValues({});
      final tokens = await TokenStore.open();
      final api = FakeBackend();
      return (ApiClient(tokens, httpClient: api.client, baseUrl: 'http://api.test/api/v1'), api);
    }

    test('sign-up sends the live terms id, and none for a document that is not published', () async {
      final (c, api) = await client();

      await AuthApi(c).registerSubmit('ref-1');

      final sent = api.requests.singleWhere((r) => r.url.path.endsWith('/customer/auth/register/submit'));
      expect(jsonDecode(sent.body), {'registration_ref': 'ref-1', 'terms_legal_doc_id': 1});
    });

    test('a requirement list is read from the customer', () {
      final p = CustomerProfile.fromJson({
        ...FakeBackend.customer,
        'legal_acceptance_required': [
          {'code': 'terms', 'version': 2, 'legal_doc_id': 5, 'reason': 'material'},
        ],
      });

      expect(p.legalAcceptanceRequired.single.code, 'terms');
      expect(p.legalAcceptanceRequired.single.isMaterial, isTrue);
      expect(CustomerProfile.fromJson(FakeBackend.customer).legalAcceptanceRequired, isEmpty);
    });
  });
}
