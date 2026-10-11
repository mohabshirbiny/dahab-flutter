import 'dart:io';

import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/core/text/keys/all_keys.dart';
import 'package:dahab_app/core/text/keys/patterns.dart';
import 'package:dahab_app/core/text/texts_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend spec 019 (T061, FR-035): every customer-visible sentence the screens hand to a
/// translated widget is in the catalogue, so staff can edit it, and a published change reaches
/// the screen through `context.t` without a release.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // Words that are not sentences: the brand, units, symbols and ids.
  const allowed = <String>{'Dahab', 'IGI', 'EGP', 'g', 'K', '·', '—', '–', '+', '-', '%', '16000'};

  test('every literal handed to a translated widget is a key, a pattern, or on the allow-list', () {
    final keyed = {for (final k in allTextKeys) norm(k.en)};
    final patterns = [for (final p in PatternKeys.table) RegExp(p.expression)];
    final widgets = RegExp(r"\b(?:T|DLabel|DButton(?:\.ghost|\.danger)?|DNote|DError|DPill)\(\s*'((?:[^'\\$\n])+)'\s*[,)]");

    final missing = <String, String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.contains('/core/text/') || path.contains('/core/i18n/') || path.contains('/mock/') || path.endsWith('/account/invite_screen.dart')) continue;
      for (final m in widgets.allMatches(f.readAsStringSync())) {
        final text = norm(m.group(1)!);
        if (text.length < 2 || allowed.contains(text) || keyed.contains(text)) continue;
        if (RegExp('invite|referral', caseSensitive: false).hasMatch(text)) continue; // the mock Invite screen, spec 019 OD-2
        if (patterns.any((p) => p.hasMatch(text))) continue;
        missing[text] = path;
      }
    }

    expect(missing, isEmpty, reason: 'not in the catalogue; run tool/gen_text_catalogue.py and regenerate the manifest');
  });

  group('a published sentence reaches a plain translated widget', () {
    late LangController lang;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      lang = await LangController.load();
    });

    Future<void> show(WidgetTester tester, TextsController texts, Widget child) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LangController>.value(value: lang),
            ChangeNotifierProvider<TextsController>.value(value: texts),
          ],
          child: Directionality(textDirection: TextDirection.ltr, child: child),
        ),
      );
    }

    Widget probe(String en) => Builder(builder: (context) => Text(context.t(en)));

    // The same key set the app ships, with a bundle that carries one sentence.
    TextsController withBundle(Map<String, ({String en, String ar})> texts) {
      final c = _Seeded(texts);
      addTearDown(c.dispose);
      return c;
    }

    testWidgets('a fixed sentence, in both languages', (tester) async {
      final c = withBundle({'browse.search_pieces': (en: 'Look for a piece', ar: 'دوّر على حاجة')});

      await show(tester, c, probe('Search pieces'));
      expect(find.text('Look for a piece'), findsOneWidget);

      lang.setLang(AppLang.ar);
      await tester.pump();
      expect(find.text('دوّر على حاجة'), findsOneWidget);
    });

    testWidgets('a sentence with a number: the group fills the placeholder of that name', (tester) async {
      final c = withBundle({PatternKeys.patternCountSaved.key: (en: 'Saved: {count}', ar: 'محفوظ: {count}')});

      await show(tester, c, probe('3 saved'));
      expect(find.text('Saved: 3'), findsOneWidget);
    });

    testWidgets('nothing published: the screen shows what it always did', (tester) async {
      final c = withBundle({});

      await show(tester, c, probe('Search pieces'));
      expect(find.text('Search pieces'), findsOneWidget);

      lang.setLang(AppLang.ar);
      await tester.pump();
      expect(find.text('دوّر على قطعة'), findsOneWidget);
    });

    testWidgets('an override that names something unknown falls back to the app wording', (tester) async {
      final c = withBundle({'browse.search_pieces': (en: 'Look for {nothing}', ar: 'دوّر على {nothing}')});

      await show(tester, c, probe('Search pieces'));
      expect(find.text('Search pieces'), findsOneWidget);
    });
  });
}

/// A controller that already holds a bundle, with no server behind it.
class _Seeded extends TextsController {
  _Seeded(Map<String, ({String en, String ar})> texts) : super(api: null) {
    seedForTest(texts);
  }
}
