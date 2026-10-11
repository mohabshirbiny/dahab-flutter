import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Backend spec 019 (SC-003, R4): no customer-visible text in a migrated screen is hard-wired.
/// Stage 1 is the spec 018 screens: the free-relist card and the seller's notes on the order
/// screen, the relist form and the rating screen. A sentence, label or button there must come
/// from `context.k(OrdersAfterCollectionKeys.…)`; a bare English literal fails this test.
///
/// What is allowed to stay a literal: identifiers (icon names such as `circle-check`, query
/// keys, route names) — they are one word with no space and do not start with a capital.
void main() {
  /// Text between two markers of a source file, comments removed.
  String region(String path, String from, String to) {
    final source = File(path).readAsStringSync().replaceAll('\r\n', '\n');
    final start = source.indexOf(from);
    expect(start, isNonNegative, reason: '$path: marker "$from" moved; update the test');
    final end = to.isEmpty ? source.length : source.indexOf(to, start);
    expect(end, greaterThan(start), reason: '$path: marker "$to" moved; update the test');
    return source.substring(start, end).split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
  }

  List<String> bareText(String code) {
    final found = <String>[];
    for (final m in RegExp(r"'((?:[^'\\]|\\.)*)'").allMatches(code)) {
      final s = m.group(1)!;
      if (!RegExp(r'[A-Za-z]').hasMatch(s)) continue;
      final sentence = s.contains(' ') || RegExp(r'^[A-Z]').hasMatch(s);
      if (sentence) found.add(s);
    }
    return found;
  }

  test('the order screen: the free-relist card, the seller note and the rating line', () {
    const path = 'lib/features/orders/order_screen.dart';
    final after = region(path, 'List<Widget> _afterCollection(', "/// The seller's latest request for more time.");
    final card = region(path, 'class _FreeRelistCard extends', '/// The green "+ 24,000 EGP" panel.');
    expect(bareText(after), isEmpty, reason: 'order screen _afterCollection still has literal text');
    expect(bareText(card), isEmpty, reason: 'the free-relist card still has literal text');
  });

  test('the relist form and the rating screen', () {
    const path = 'lib/features/orders/order_help_screens.dart';
    final stage1 = region(path, '// ---- Backend spec 018: after collection ----', '');
    expect(bareText(stage1), isEmpty, reason: 'a Stage 1 screen still has literal text');
  });

  test('the Stage 1 screens read their texts through keys', () {
    final order = File('lib/features/orders/order_screen.dart').readAsStringSync();
    final help = File('lib/features/orders/order_help_screens.dart').readAsStringSync();
    expect(RegExp(r'OrdersAfterCollectionKeys\.\w+').allMatches(order).length, greaterThanOrEqualTo(10));
    expect(RegExp(r'OrdersAfterCollectionKeys\.\w+').allMatches(help).length, greaterThanOrEqualTo(30));
  });

  test('every Stage 1 key is used by a screen', () {
    final screens = '${File('lib/features/orders/order_screen.dart').readAsStringSync()}${File('lib/features/orders/order_help_screens.dart').readAsStringSync()}';
    final catalogue = File('lib/core/text/keys/orders_after_collection.dart').readAsStringSync();
    final names = RegExp(r'static const (\w+) = TextKey\(').allMatches(catalogue).map((m) => m.group(1)!);
    final unused = [for (final n in names) if (!screens.contains('OrdersAfterCollectionKeys.$n')) n];
    expect(unused, isEmpty, reason: 'declared keys no screen reads');
  });

  test('there is no invite or referral text on the Stage 1 screens (spec 018 FR-038)', () {
    // The words customers can read: the string literals, not the comments that explain them.
    final catalogue = File('lib/core/text/keys/orders_after_collection.dart')
        .readAsStringSync()
        .split(RegExp(r'\r?\n'))
        .where((l) => !l.trimLeft().startsWith('//'))
        .join(' ')
        .toLowerCase();
    final help = region('lib/features/orders/order_help_screens.dart', '// ---- Backend spec 018: after collection ----', '').toLowerCase();
    for (final word in ['invite', 'referral', 'refer a friend']) {
      expect(catalogue.contains(word), isFalse, reason: 'catalogue mentions "$word"');
      expect(help.contains(word), isFalse, reason: 'rating/relist screen mentions "$word"');
    }
  });
}
