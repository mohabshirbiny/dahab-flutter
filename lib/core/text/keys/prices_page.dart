import '../text_key.dart';

/// Where prices come from, without Rapaport (owner notes of 2026-10-29): Evolve prices the gold,
/// IGI grades the stones; the sell form's stone guide no longer names Rapaport either.
/// `account.prices.*`, `sell.stone_guide`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class PricesPageKeys {
  static const intro = TextKey(
    'account.prices.intro',
    'An independent reference decides what your gold is worth, not us. Evolve prices the gold and IGI checks every piece.',
    ar: 'مرجع مستقل هو اللي بيحدد قيمة دهبك، مش إحنا. Evolve بتسعّر الدهب وIGI بتفحص كل قطعة.',
    area: 'Account',
    where: 'Settings and legal screens',
  );
  static const stoneGuide = TextKey(
    'sell.stone_guide',
    'A guide only, not a valuation. IGI confirms the grade and value.',
    ar: 'ده استرشادي بس، مش تقييم. IGI بتأكد الدرجة والقيمة.',
    area: 'Selling',
    where: 'Sell: step 1',
  );

  static const all = [intro, stoneGuide];
}
