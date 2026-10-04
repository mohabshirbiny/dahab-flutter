import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dahab_app/core/utils/format.dart' as fmt;

void main() {
  // Like the Dashboard's formatMoney: piastres only when there are any, then two digits.
  test('money shows piastres only when there are any', () {
    expect(fmt.money(20000), '20,000 EGP');
    expect(fmt.money(109584.75), '109,584.75 EGP');
    expect(fmt.money(0), '0 EGP');
    expect(fmt.money(19900.5), '19,900.50 EGP');
    expect(fmt.money(0.5), '0.50 EGP');
    expect(fmt.money(1000.004), '1,000 EGP');
    expect(fmt.signedMoney(-15000.5), '- 15,000.50 EGP');
    expect(fmt.signedMoney(-400), '- 400 EGP');
    expect(fmt.signedMoney(54684.75), '+ 54,684.75 EGP');
    expect(fmt.amount(1234.567), '1,234.57');
  });

  // Rates and weights keep the prototype's whole numbers.
  test('group still rounds to whole numbers', () {
    expect(fmt.group(4512.6), '4,513');
  });

  test('Arabic money patterns accept piastres', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final lang = await LangController.load();
    lang.setLang(AppLang.ar);

    expect(lang.t('109,584.75 EGP'), '109,584.75 جنيه');
    expect(lang.t('+ 54,684.75 EGP'), '+ 54,684.75 جنيه');
    expect(lang.t('28 Aug, balance 109,584.75 EGP'), '28 Aug · الرصيد 109,584.75 جنيه');
  });

  test('dates follow the app language', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final lang = await LangController.load();
    final at = DateTime(2026, 10, 5, 14, 7);

    expect(fmt.whenOf(at), '5 Oct, 14:07');
    expect(fmt.dayMonth(at), '5 Oct');
    expect(fmt.dayMonthYear(at), '5 Oct 2026');
    expect(fmt.monthYear(at), 'October 2026');

    lang.setLang(AppLang.ar);
    expect(fmt.whenOf(at), '5 أكتوبر، 14:07');
    expect(fmt.dayMonth(at), '5 أكتوبر');
    expect(fmt.dayMonthYear(at), '5 أكتوبر 2026');
    expect(fmt.monthYear(at), 'أكتوبر 2026');
    expect(
      lang.t('You accepted a buyer (order DH-2026-000012). Bring the piece to Nasr City by ${fmt.whenOf(at)}.'),
      'قبلت مشتري (طلب DH-2026-000012). وصّل القطعة لفرع Nasr City قبل 5 أكتوبر، 14:07.',
    );
    expect(lang.t('Collect before ${fmt.whenOf(at)}'), 'الاستلام قبل 5 أكتوبر، 14:07');

    lang.setLang(AppLang.en);
    expect(fmt.whenOf(at), '5 Oct, 14:07');
  });
}
