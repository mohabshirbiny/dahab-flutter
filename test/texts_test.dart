import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/core/text/keys/orders_after_collection.dart';
import 'package:dahab_app/core/text/text_bundle.dart';
import 'package:dahab_app/core/text/texts_controller.dart';
import 'package:dahab_app/core/text/texts_store.dart';
import 'package:dahab_app/services/api/api_client.dart';
import 'package:dahab_app/services/api/content_api.dart';
import 'package:dahab_app/services/api/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// Backend spec 019 (Q3, FR-005, FR-007): published texts reach the app, and an outage, a
/// missing key, a missing language or an unfillable placeholder never breaks a screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const title = OrdersAfterCollectionKeys.freeRelistCardTitle;
  const left = OrdersAfterCollectionKeys.freeRelistCardLeftHoursMinutes;
  const codeTitleEn = 'Sell it again with no commission';
  const codeTitleAr = 'بيعها تاني من غير عمولة';

  late LangController lang;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lang = await LangController.load();
  });

  Future<({TextsController texts, FakeBackend api, TextsStore store})> make({FakeBackend? backend}) async {
    final api = backend ?? FakeBackend();
    final tokens = await TokenStore.open();
    final client = ApiClient(tokens, httpClient: api.client, baseUrl: 'http://api.test/api/v1');
    final store = TextsStore();
    final texts = TextsController(api: ContentApi(client), store: store);
    addTearDown(texts.dispose);
    return (texts: texts, api: api, store: store);
  }

  group('what the app shows', () {
    test('with no bundle, the code text, in both languages', () async {
      final c = TextsController();
      expect(c.resolve(title, lang), codeTitleEn);
      lang.setLang(AppLang.ar);
      expect(c.resolve(title, lang), codeTitleAr);
    });

    test('a published override replaces both languages', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'Relist it for free', 'ar': 'اعرضها تاني ببلاش'},
        };
      await m.texts.refresh();

      expect(m.texts.resolve(title, lang), 'Relist it for free');
      lang.setLang(AppLang.ar);
      expect(m.texts.resolve(title, lang), 'اعرضها تاني ببلاش');
    });

    test('a key the bundle does not carry, and an unknown key in the bundle, change nothing', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          'order.some.future_key': {'en': 'Future', 'ar': 'مستقبل'},
        };
      await m.texts.refresh();

      expect(m.texts.bundle.texts.keys, ['order.some.future_key']);
      expect(m.texts.resolve(title, lang), codeTitleEn);
    });

    test('an empty language falls back to the code text for that language only', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'Relist it for free', 'ar': '  '},
        };
      await m.texts.refresh();

      expect(m.texts.resolve(title, lang), 'Relist it for free');
      lang.setLang(AppLang.ar);
      expect(m.texts.resolve(title, lang), codeTitleAr);
    });

    test('placeholders are filled from the screen and from the settings', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTextSettings = {'commission_gold_pct': '20'}
        ..appTexts = {
          left.key: {'en': '{hours} h {minutes} min left, then {commission_gold_pct}% applies', 'ar': 'فاضل {hours} ساعة و{minutes} دقيقة، وبعدها {commission_gold_pct}٪'},
        };
      await m.texts.refresh();

      expect(m.texts.resolve(left, lang, {'hours': 3, 'minutes': 20}), '3 h 20 min left, then 20% applies');
    });

    test('a value with a placeholder the app cannot fill shows the code text, never a raw {name}', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          left.key: {'en': '{hours} h {minutes} min left of {mystery}', 'ar': 'فاضل {hours} ساعة و{mystery}'},
        };
      await m.texts.refresh();

      expect(m.texts.resolve(left, lang, {'hours': 3, 'minutes': 20}), '3 h 20 min left');
      lang.setLang(AppLang.ar);
      expect(m.texts.resolve(left, lang, {'hours': 3, 'minutes': 20}), 'فاضل 3 ساعة و20 دقيقة');
    });

    test('the code text keeps the Arabic the dictionary patterns already gave', () {
      final c = TextsController();
      lang.setLang(AppLang.ar);
      expect(c.resolve(OrdersAfterCollectionKeys.freeRelistCardLeftMinutes, lang, {'minutes': 45}), 'فاضل 45 دقيقة');
      expect(c.resolve(OrdersAfterCollectionKeys.ratingGivenNote, lang, {'stars': 4}), 'You rated this order 4 out of 5.');
    });
  });

  group('the bundle on the device and on the wire', () {
    test('the saved copy shows while the network is down, and nothing saved shows the code text', () async {
      final first = await make();
      first.api
        ..appTextsVersion = 3
        ..appTexts = {
          title.key: {'en': 'Relist it for free', 'ar': 'اعرضها تاني ببلاش'},
        };
      await first.texts.refresh();

      // A later start with the Backend unreachable: the saved copy is what shows.
      final down = FakeBackend()..appTextsDown = true;
      final second = await make(backend: down);
      expect(second.texts.resolve(title, lang), codeTitleEn);
      await second.texts.loadSaved();
      await second.texts.refresh();
      expect(second.texts.resolve(title, lang), 'Relist it for free');

      // Cleared storage and still offline: the code text, no error.
      SharedPreferences.setMockInitialValues({});
      final third = await make(backend: FakeBackend()..appTextsDown = true);
      await third.texts.loadSaved();
      await third.texts.refresh();
      expect(third.texts.resolve(title, lang), codeTitleEn);
    });

    test('an unchanged bundle answers 304 and is not downloaded again', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'One', 'ar': 'واحد'},
        };
      await m.texts.refresh();
      await m.texts.refresh();
      await m.texts.refresh();
      expect(m.api.appTextsReads, 1);
    });

    test('a publish refreshes the texts', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'One', 'ar': 'واحد'},
        };
      await m.texts.refresh();
      m.api
        ..appTextsVersion = 2
        ..appTexts = {
          title.key: {'en': 'Two', 'ar': 'اتنين'},
        };
      await m.texts.refresh();

      expect(m.texts.resolve(title, lang), 'Two');
      expect(m.api.appTextsReads, 2);
    });

    test('a setting change alone refreshes the values, with no text republished', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTextSettings = {'commission_gold_pct': '20'}
        ..appTexts = {
          title.key: {'en': 'Pay {commission_gold_pct}%', 'ar': 'ادفع {commission_gold_pct}٪'},
        };
      await m.texts.refresh();
      expect(m.texts.resolve(title, lang), 'Pay 20%');

      m.api.appTextSettings = {'commission_gold_pct': '18'};
      await m.texts.refresh();

      expect(m.texts.resolve(title, lang), 'Pay 18%');
      expect(m.api.appTextsReads, 2);
    });

    test('a revert to default removes the key from the bundle and the app shows its own default', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'Relist it for free', 'ar': 'اعرضها تاني ببلاش'},
        };
      await m.texts.refresh();
      expect(m.texts.resolve(title, lang), 'Relist it for free');

      // The Backend ends the override: the key is simply absent from the next bundle.
      m.api
        ..appTextsVersion = 2
        ..appTexts = {};
      await m.texts.refresh();

      expect(m.texts.resolve(title, lang), codeTitleEn);
    });

    test('a failed refresh keeps what the app holds', () async {
      final m = await make();
      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'One', 'ar': 'واحد'},
        };
      await m.texts.refresh();

      m.api.appTextsDown = true;
      await m.texts.refresh();

      expect(m.texts.resolve(title, lang), 'One');
    });

    test('a bundle that cannot be read is ignored', () {
      final bundle = TextBundle.fromJson({
        'version': 'x',
        'texts': {
          'a.b': {'en': 1, 'ar': 'x'},
          'c.d': 'nope',
          'e.f': {'en': 'ok', 'ar': 'تمام'},
        },
        'settings': 5,
      });
      expect(bundle.texts.keys, ['e.f']);
      expect(bundle.settings, isEmpty);
    });
  });

  group('on a screen', () {
    Widget host(TextsController texts) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: lang),
        ChangeNotifierProvider.value(value: texts),
      ],
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) => Text(context.k(title))),
      ),
    );

    testWidgets('context.k shows the code text, then the override once it is published', (tester) async {
      final m = await tester.runAsync(make);
      await tester.pumpWidget(host(m!.texts));
      expect(find.text(codeTitleEn), findsOneWidget);

      m.api
        ..appTextsVersion = 1
        ..appTexts = {
          title.key: {'en': 'Relist it for free', 'ar': 'اعرضها تاني ببلاش'},
        };
      await tester.runAsync(m.texts.refresh);
      await tester.pump();

      expect(find.text('Relist it for free'), findsOneWidget);
      lang.setLang(AppLang.ar);
      await tester.pump();
      expect(find.text('اعرضها تاني ببلاش'), findsOneWidget);
    });

    testWidgets('context.k works with no TextsController above (a bare widget)', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lang,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(builder: (context) => Text(context.k(title))),
          ),
        ),
      );
      expect(find.text(codeTitleEn), findsOneWidget);
    });
  });
}
