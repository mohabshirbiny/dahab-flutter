import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/core/text/texts_controller.dart';
import 'package:dahab_app/features/account/settings_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How prices work: the commission card reads its figures from the settings in the text
/// bundle, never from numbers typed in the code.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LangController lang;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lang = await LangController.load();
  });

  Future<void> show(WidgetTester tester, Map<String, Object?> settings) async {
    final texts = _Seeded(settings);
    addTearDown(texts.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LangController>.value(value: lang),
          ChangeNotifierProvider<TextsController>.value(value: texts),
        ],
        child: const MaterialApp(home: Scaffold(body: CommissionCard())),
      ),
    );
  }

  testWidgets('the card shows the live settings', (tester) async {
    await show(tester, {'commission_gold_pct': '18', 'commission_stone_pct': '7', 'commission_minimum_egp': '250'});

    expect(find.text('18% of the making charge'), findsOneWidget);
    expect(find.text('7% of the full price'), findsOneWidget);
    expect(find.text('250 EGP'), findsOneWidget);
    expect(find.textContaining('with gold or without, it is 7% of the full price'), findsOneWidget);
  });

  testWidgets('the card waits until the settings are known', (tester) async {
    await show(tester, {});

    expect(find.textContaining('of the full price'), findsNothing);
  });
}

class _Seeded extends TextsController {
  _Seeded(Map<String, Object?> settings) : super(api: null) {
    seedForTest({}, settings: settings);
  }
}
