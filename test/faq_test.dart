import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/core/text/keys/account_help.dart';
import 'package:dahab_app/core/text/texts_controller.dart';
import 'package:dahab_app/services/api/api_client.dart';
import 'package:dahab_app/services/api/content_api.dart';
import 'package:dahab_app/services/api/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_app.dart';

/// Backend spec 019 US5: the Help questions are the ones staff published, in their order and in
/// the customer's language, with the numbers the system owns filled in. No published entry, no
/// questions: the app has no Help of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LangController lang;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lang = await LangController.load();
  });

  Future<(TextsController, FakeBackend)> make() async {
    final api = FakeBackend();
    final tokens = await TokenStore.open();
    final client = ApiClient(tokens, httpClient: api.client, baseUrl: 'http://api.test/api/v1');
    final texts = TextsController(api: ContentApi(client));
    addTearDown(texts.dispose);
    return (texts, api);
  }

  Map<String, Object?> entry(String key, int position, String qEn, String qAr, String aEn, String aAr) => {
    'key': key,
    'position': position,
    'question': {'en': qEn, 'ar': qAr},
    'answer': {'en': aEn, 'ar': aAr},
  };

  test('nothing published: no questions', () async {
    final (texts, _) = await make();
    await texts.refresh();

    expect(texts.faq(lang), isEmpty);
    expect(AccountHelpKeys.empty.en, 'Nothing here yet. Contact us if you have a question.');
  });

  test('the published entries, in the order the server sent, in the language chosen', () async {
    final (texts, api) = await make();
    api
      ..appTextsVersion = 1
      ..appFaq = [
        entry('help.faq.a', 1, 'First?', 'الأول؟', 'Yes.', 'أيوه.'),
        entry('help.faq.b', 2, 'Second?', 'التاني؟', 'No.', 'لأ.'),
      ];
    await texts.refresh();

    expect(texts.faq(lang).map((e) => e.question), ['First?', 'Second?']);
    lang.setLang(AppLang.ar);
    final ar = texts.faq(lang);
    expect(ar.map((e) => e.question), ['الأول؟', 'التاني؟']);
    expect(ar.first.answer, 'أيوه.');
  });

  test('a number the system owns is filled from the bundle; an entry that cannot be filled is left out', () async {
    final (texts, api) = await make();
    api
      ..appTextsVersion = 1
      ..appTextSettings = {'commission_gold_pct': '20'}
      ..appFaq = [
        entry('help.faq.cost', 1, 'Cost?', 'التكلفة؟', 'We take {commission_gold_pct}%.', 'بناخد {commission_gold_pct}%.'),
        entry('help.faq.broken', 2, 'Broken?', 'مكسور؟', 'Takes {not_a_setting}.', 'بياخد {not_a_setting}.'),
      ];
    await texts.refresh();

    final faq = texts.faq(lang);
    expect(faq, hasLength(1));
    expect(faq.single.answer, 'We take 20%.');
  });

  test('an empty Arabic half shows the English', () async {
    final (texts, api) = await make();
    api
      ..appTextsVersion = 1
      ..appFaq = [entry('help.faq.a', 1, 'First?', '', 'Yes.', '')];
    await texts.refresh();
    lang.setLang(AppLang.ar);

    expect(texts.faq(lang).single.question, 'First?');
  });
}
