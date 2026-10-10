import 'dart:convert';
import 'dart:io';

import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/core/text/keys/all_keys.dart';
import 'package:dahab_app/core/text/text_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend spec 019 R1: the app's own key catalogue is the source of the keys and their
/// defaults. `assets/text/keys.json` is generated from it and checked here, so a key that was
/// added, changed or removed without regenerating the manifest fails a test instead of
/// reaching the Backend's registry unannounced. The Backend keeps a copy at
/// `database/data/app_text_keys.json` and `php artisan app-texts:sync` reads it.
///
/// To regenerate after a change: `UPDATE_TEXT_MANIFEST=1 flutter test test/text_manifest_test.dart`,
/// then copy `assets/text/keys.json` to the Backend (`database/data/app_text_keys.json`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final keyFormat = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+){1,5}$');
  final manifestFile = File('assets/text/keys.json');

  Future<Map<String, dynamic>> build() async {
    final lang = await LangController.load();
    return {
      'version': 1,
      'keys': [
        for (final k in allTextKeys)
          {
            'key': k.key,
            'kind': 'app',
            'area': k.area,
            'where': k.where,
            'default_en': k.en,
            'default_ar': k.ar ?? lang.arabicFor(k.en) ?? k.en,
            'placeholders': TextKey.namesIn(k.en),
            'max_length': k.limit,
          },
      ],
    };
  }

  test('every key is readable, unique, documented and declares exactly the placeholders it uses', () {
    final seen = <String>{};
    for (final k in allTextKeys) {
      expect(keyFormat.hasMatch(k.key), isTrue, reason: '${k.key} is not <screen>.<part>.<purpose>');
      expect(seen.add(k.key), isTrue, reason: 'duplicate key ${k.key}');
      expect(k.en.trim(), isNotEmpty, reason: '${k.key} has no default');
      expect(k.area, isNotEmpty, reason: '${k.key} has no area');
      expect(k.where, isNotEmpty, reason: '${k.key} has no "where it appears"');
      expect(k.placeholders, TextKey.namesIn(k.en), reason: '${k.key}: declared placeholders differ from the ones in the text');
      // An explicit Arabic default must use the same placeholders; without one, the Arabic is looked up
      // from the English (or is the English itself when the app has never translated it).
      if (k.ar != null) {
        expect(TextKey.namesIn(k.ar!), k.placeholders, reason: '${k.key}: the Arabic default must use the same placeholders');
      }
    }
  });

  test('the catalogue source lists every key it declares', () {
    final source = File('lib/core/text/keys/orders_after_collection.dart').readAsStringSync();
    final declared = RegExp(r'static const (\w+) = TextKey\(').allMatches(source).length;
    final listed = allTextKeys.length;
    expect(listed, declared, reason: 'a TextKey was declared but is missing from `all`, or the other way round');
  });

  test('the manifest matches the catalogue, and nothing was removed without being retired', () async {
    final built = await build();
    if (Platform.environment['UPDATE_TEXT_MANIFEST'] == '1') {
      var retired = <dynamic>[];
      if (manifestFile.existsSync()) {
        final old = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
        retired = [...(old['retired'] as List? ?? const [])];
      }
      built['retired'] = retired;
      manifestFile.createSync(recursive: true);
      manifestFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(built)}\n');
    }

    expect(manifestFile.existsSync(), isTrue, reason: 'assets/text/keys.json is missing; run with UPDATE_TEXT_MANIFEST=1');
    final onDisk = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;

    final diskKeys = {for (final e in onDisk['keys'] as List) (e as Map)['key'] as String};
    final retired = {...(onDisk['retired'] as List? ?? const []).cast<String>()};
    final current = {for (final k in allTextKeys) k.key};
    final removed = diskKeys.difference(current).difference(retired);
    expect(removed, isEmpty, reason: 'keys are never removed (Q1): list them under "retired" in assets/text/keys.json');

    expect(onDisk['version'], built['version']);
    expect(onDisk['keys'], built['keys'], reason: 'regenerate: UPDATE_TEXT_MANIFEST=1 flutter test test/text_manifest_test.dart');
  });

  test('every default has an Arabic default, and only the ones the app never translated fall back to English', () async {
    final built = await build();
    final untranslated = [
      for (final e in built['keys'] as List)
        if ((e as Map)['default_ar'] == e['default_en']) e['key'] as String,
    ];
    // Spec 018 left "You rated this order N out of 5." without Arabic; it shows in English today and
    // keeps doing so until the owner approves the Arabic (spec 019 Appendix B).
    expect(untranslated, ['order.rating.given_note']);
  });

  test('the Backend copy is the same file', () {
    final copy = File('../dahab-backend/database/data/app_text_keys.json');
    if (!copy.existsSync()) {
      // The Backend checkout is a worktree on some machines; the copy is checked there too
      // (Backend test SyncAppTextsTest reads it).
      return;
    }
    expect(jsonDecode(copy.readAsStringSync()), jsonDecode(manifestFile.readAsStringSync()));
  });
}
