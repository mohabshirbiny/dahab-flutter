import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../utils/format.dart' show arabicDates;
import 'ar_extra.dart';

enum AppLang { en, ar }

/// Local, mock language switcher.
///
/// The prototype translates by English source string: every visible string
/// is looked up in `AR_DICT` (extracted verbatim to `assets/i18n/ar.json`),
/// then in a list of regex patterns for strings with numbers in them. This
/// class keeps exactly that model so the Arabic copy stays identical to the
/// prototype. Strings with no Arabic entry fall back to English, as they do
/// in the prototype.
class LangController extends ChangeNotifier {
  LangController._(this._dict) {
    arabicDates = false;
  }

  final Map<String, String> _dict;
  AppLang _lang = AppLang.en;

  static Future<LangController> load() async {
    final raw = await rootBundle.loadString('assets/i18n/ar.json');
    final dict = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    return LangController._({...arExtra, ...dict});
  }

  AppLang get lang => _lang;
  bool get isArabic => _lang == AppLang.ar;
  TextDirection get direction => isArabic ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => isArabic ? const Locale('ar', 'EG') : const Locale('en');

  void setLang(AppLang lang) {
    if (lang == _lang) return;
    _lang = lang;
    arabicDates = lang == AppLang.ar;
    notifyListeners();
  }

  void toggle() => setLang(isArabic ? AppLang.en : AppLang.ar);

  /// Translate an English source string for the current language.
  String t(String en) {
    if (!isArabic) return en;
    return arabicFor(en) ?? en;
  }

  /// Arabic translation, or null when the prototype has none (`tr()` in JS).
  String? arabicFor(String en) {
    final key = en.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hit = _dict[key] ?? _dict[en];
    if (hit != null) return hit;
    for (final (re, template) in _patterns) {
      final m = re.firstMatch(key);
      if (m != null) {
        return template.replaceAllMapped(RegExp(r'\$(\d)'), (g) => m.group(int.parse(g.group(1)!)) ?? '');
      }
    }
    return null;
  }

  /// `AR_PATTERNS` from the prototype.
  static final List<(RegExp, String)> _patterns = [
    (RegExp(r'^Making charge (\d[\d,]*) per gram$'), r'مصنعية $1 للجرام'),
    (RegExp(r'^(\d+)K, ([\d.]+) g$'), r'عيار $1، $2 جرام'),
    (RegExp(r'^(\d+)K with stones, ([\d.]+) g$'), r'عيار $1 مكسّة، $2 جرام'),
    (RegExp(r'^Mixed, ([\d.]+) g and stone$'), r'مكسّة، $1 جرام وحجر'),
    (RegExp(r'^(\d+) of (\d+) required added$'), r'$1 من $2 مطلوبة اتضافت'),
    (RegExp(r'^\((\d+)% of the making charge\)$'), r'($1٪ من المصنعية)'),
    (RegExp(r'^\((\d+)% of the value you add\)$'), r'($1٪ من القيمة اللي بتضيفها)'),
    (RegExp(r'^\((\d+)%\)$'), r'($1٪)'),
    (RegExp(r'^\(minimum (\d+) EGP\)$'), r'(الحد الأدنى $1 جنيه)'),
    (RegExp(r'^\(minimum\)$'), r'(الحد الأدنى)'),
    // Sentences with a date and an order (specs 011–012); the date is already in the app's language.
    (
      RegExp(r'^The seller accepted your request \(order (.+?)\)\. Your deposit is held and the seller brings the piece to (.+?) by (.+)\.$'),
      r'البايع قبل طلبك (طلب $1). عربونك محجوز والبايع هيوصل القطعة لفرع $2 قبل $3.',
    ),
    (
      RegExp(
        r'^Your request is in the queue\. You are next in line\. The seller replies by (.+?)\. If the seller takes someone ahead of you, declines, or does not reply in time, your deposit comes back in full at once\.$',
      ),
      r'طلبك في الطابور. إنت اللي عليك الدور. البايع بيرد قبل $1. لو البايع أخد حد قبلك، أو رفض، أو مارَدّش في الميعاد، عربونك بيرجعلك كامل على طول.',
    ),
    (
      RegExp(
        r'^Your request is in the queue\. There is 1 buyer ahead of you\. The seller replies by (.+?)\. If the seller takes someone ahead of you, declines, or does not reply in time, your deposit comes back in full at once\.$',
      ),
      r'طلبك في الطابور. فيه مشتري واحد قبلك. البايع بيرد قبل $1. لو البايع أخد حد قبلك، أو رفض، أو مارَدّش في الميعاد، عربونك بيرجعلك كامل على طول.',
    ),
    (
      RegExp(
        r'^Your request is in the queue\. There are (\d+) buyers ahead of you\. The seller replies by (.+?)\. If the seller takes someone ahead of you, declines, or does not reply in time, your deposit comes back in full at once\.$',
      ),
      r'طلبك في الطابور. فيه $1 مشترين قبلك. البايع بيرد قبل $2. لو البايع أخد حد قبلك، أو رفض، أو مارَدّش في الميعاد، عربونك بيرجعلك كامل على طول.',
    ),
    (RegExp(r'^You accepted a buyer \(order (.+?)\)\. Bring the piece to (.+?) by (.+)\.$'), r'قبلت مشتري (طلب $1). وصّل القطعة لفرع $2 قبل $3.'),
    (RegExp(r'^Accepted\. Bring the piece to (.+?) by (.+)\.$'), r'اتقبل. وصّل القطعة لفرع $1 قبل $2.'),
    (RegExp(r'^Collect before (.+)$'), r'الاستلام قبل $1'),
    (RegExp(r'^(.+), balance ([\d,.\-]+) EGP$'), r'$1 · الرصيد $2 جنيه'),
    (RegExp(r'^(\d[\d,]*(?:\.\d+)?) EGP$'), r'$1 جنيه'),
    (RegExp(r'^\+ (\d[\d,]*(?:\.\d+)?) EGP$'), r'+ $1 جنيه'),
    (RegExp(r'^− (\d[\d,]*(?:\.\d+)?) EGP$'), r'− $1 جنيه'),
    (RegExp(r'^- (\d[\d,]*(?:\.\d+)?) EGP$'), r'− $1 جنيه'),
    (RegExp(r'^([\d.]+) g$'), r'$1 جرام'),
    (RegExp(r'^(\d+) /g$'), r'$1 للجرام'),
    (RegExp(r'^(\d+)K$'), r'عيار $1'),
    (RegExp(r'^Use ([\d.]+) g$'), r'استخدم $1 جرام'),
    (RegExp(r'^(\d+) of (\d+)$'), r'$1 من $2'),
    (RegExp(r'^(\d+) saved$'), r'$1 محفوظة'),
    (RegExp(r'^(\d+) records$'), r'$1 سجل'),
    (RegExp(r'^(\d+) unread$'), r'$1 غير مقروء'),
    (RegExp(r'^get ([\d,]+)$'), r'بيع بـ $1'),
    (RegExp(r'^pay ([\d,]+)$'), r'اشتري بـ $1'),
    (RegExp(r'^(\d+)K ([\d,]+)$'), r'عيار $1 · $2'),
    (RegExp(r'^(.+) · added (.+)$'), r'$1 · اتضاف $2'),
    (RegExp(r'^(.+) ending ([\d]+)$'), r'$1 المنتهي بـ $2'),
    (RegExp(r'^(.+) ending ([\d]+), (.+)$'), r'$1 المنتهي بـ $2، $3'),
    (RegExp(r'^(.+), name checked against ID$'), r'$1، الاسم اتراجع مقابل البطاقة'),
    (RegExp(r'^(.+), waiting for review$'), r'$1، في انتظار المراجعة'),
    (RegExp(r'^(.+), today$'), r'$1، النهاردة'),
    (RegExp(r'^to (.+), today$'), r'إلى $1، النهاردة'),
    (RegExp(r'^Across (\d+) order$'), r'على $1 طلب'),
    (RegExp(r'^(\d+) days listed$'), r'$1 يوم معروضة'),
    (RegExp(r'^up to ([\d,]+) a day$'), r'لحد $1 يومياً'),
    // Patterns for strings the Flutter build makes dynamic.
    (RegExp(r'^(\d+) pieces\. Every one is inspected by IGI before you pay the balance\.$'), r'$1 قطعة. كل واحدة بتتفحص من IGI قبل ما تدفع الباقي.'),
    // Backend spec 010: listing cards and the detail of a live piece.
    (RegExp(r'^Sent (\d+ \w+), ([\d.]+) g$'), r'اتبعت $1، $2 جرام'),
    (RegExp(r'^Listed (\d+ \w+), ([\d.]+) g$'), r'اتعرضت $1، $2 جرام'),
    (RegExp(r'^Started (\d+ \w+), ([\d.]+) g$'), r'بدأت $1، $2 جرام'),
    (RegExp(r'^Sent (\d+ \w+)$'), r'اتبعت $1'),
    (RegExp(r'^Listed (\d+ \w+)$'), r'اتعرضت $1'),
    (RegExp(r'^Started (\d+ \w+)$'), r'بدأت $1'),
    (RegExp(r'^(\d+) per gram$'), r'$1 للجرام'),
    (RegExp(r'^(\d+) of (\d+), plus video$'), r'$1 من $2، وفيديو'),
    (RegExp(r'^You would receive ([\d,.]+) EGP$'), r'هتستلم $1 جنيه'),
    (RegExp(r'^(\d+)K gold and diamond, ([\d.]+) g$'), r'دهب عيار $1 وألماظ، $2 جرام'),
    (RegExp(r'^Set to ([\d.]+) g\. Change it if you find the real weight\.$'), r'اتظبط على $1 جرام. غيّره لو عرفت الوزن الحقيقي.'),
    // Backend spec 012: orders.
    (RegExp(r'^Pay (\d[\d,]*(?:\.\d+)?) EGP$'), r'ادفع $1 جنيه'),
    (RegExp(r'^Collect before (.+)$'), r'استلم قبل $1'),
    (RegExp(r'^You are selling, ([\d.]+) g$'), r'بتبيع، $1 جرام'),
    (RegExp(r'^You sold this, ([\d.]+) g$'), r'بعت القطعة دي، $1 جرام'),
    (RegExp(r'^You are buying, ([\d.]+) g$'), r'بتشتري، $1 جرام'),
    (RegExp(r'^You bought this, ([\d.]+) g$'), r'اشتريت القطعة دي، $1 جرام'),
    (RegExp(r'^(DH-[\d-]+) · You are buying, ([\d.]+) g$'), r'$1 · بتشتري، $2 جرام'),
    (RegExp(r'^(DH-[\d-]+) · You are selling, ([\d.]+) g$'), r'$1 · بتبيع، $2 جرام'),
    (RegExp(r'^(DH-[\d-]+) · You are buying$'), r'$1 · بتشتري'),
    (RegExp(r'^(DH-[\d-]+) · You are selling$'), r'$1 · بتبيع'),
    (RegExp(r'^(\d+) h (\d+) min left$'), r'فاضل $1 ساعة و$2 دقيقة'),
    (RegExp(r'^(\d+) min left$'), r'فاضل $1 دقيقة'),
    // Backend spec 014: report a problem, more time, someone else collects.
    (RegExp(r'^Photo (\d+)$'), r'صورة $1'),
    (RegExp(r'^Order (DH-[\d-]+)$'), r'أوردر $1'),
    (RegExp(r'^The order is on hold and someone will be in touch today\. Your reference is (DSP-\d+)\.$'), r'الأوردر متوقف وحد هيكلمك النهاردة. الرقم المرجعي بتاعك $1.'),
    (RegExp(r'^Bring it by (.+?) · (\d+) h (\d+) min left$'), r'وصّلها قبل $1 · فاضل $2 ساعة و$3 دقيقة'),
    (RegExp(r'^Bring it by (.+)$'), r'وصّلها قبل $1'),
    (RegExp(r'^More time given: (\d+) working hours\. The deadline below is the new one\.$'), r'اتدّالك وقت زيادة: $1 ساعة عمل. المهلة اللي تحت هي الجديدة.'),
    (RegExp(r'^We could not give more time: (.+)$'), r'مقدرناش ندي وقت زيادة: $1'),
  ];
}

extension I18nContext on BuildContext {
  /// Translate and subscribe to language changes.
  String t(String en) => watch<LangController>().t(en);

  /// Translate without subscribing (for callbacks, dialogs, toasts).
  String tr(String en) => read<LangController>().t(en);

  bool get isArabic => watch<LangController>().isArabic;
}
