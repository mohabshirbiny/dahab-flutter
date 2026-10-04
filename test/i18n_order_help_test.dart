import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backend spec 014: the order-help lines that carry a number or a reference are
/// translated whole, not left in English.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('report, more time and proxy lines with numbers have Arabic', () async {
    final lang = await LangController.load();
    lang.setLang(AppLang.ar);

    expect(lang.t('Photo 2'), 'صورة 2');
    expect(lang.t('Order DH-2026-000041'), 'أوردر DH-2026-000041');
    expect(lang.t('The order is on hold and someone will be in touch today. Your reference is DSP-41.'), 'الأوردر متوقف وحد هيكلمك النهاردة. الرقم المرجعي بتاعك DSP-41.');
    expect(lang.t('Bring it by 5 Oct, 12:00 · 9 h 40 min left'), 'وصّلها قبل 5 Oct, 12:00 · فاضل 9 ساعة و40 دقيقة');
    expect(lang.t('More time given: 24 working hours. The deadline below is the new one.'), 'اتدّالك وقت زيادة: 24 ساعة عمل. المهلة اللي تحت هي الجديدة.');
    expect(lang.t('We could not give more time: The branch is open.'), 'مقدرناش ندي وقت زيادة: The branch is open.');
    expect(lang.t('Open the order first'), 'افتح الأوردر الأول');
  });
}
