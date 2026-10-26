import '../text_key.dart';

/// Sell step 1: the weight, the making charge and the asking price typed by hand (instead of
/// sliders), with what shows when a figure cannot be used. `sell.figures.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class SellFigureKeys {
  static const _area = 'Selling';
  static const _where = 'Sell: step 1';

  static const weightInvalid = TextKey(
    'sell.figures.weight_invalid',
    'Enter the weight in grams: more than 0, with at most two decimals.',
    ar: 'اكتب الوزن بالجرام: أكبر من صفر، وبحد أقصى رقمين بعد العلامة.',
    area: _area,
    where: _where,
  );
  static const amountInvalid = TextKey(
    'sell.figures.amount_invalid',
    'Enter an amount in EGP, with at most two decimals.',
    ar: 'اكتب المبلغ بالجنيه، وبحد أقصى رقمين بعد العلامة.',
    area: _area,
    where: _where,
  );
  static const fixFigures = TextKey(
    'sell.figures.fix_figures',
    'Correct the figures above to continue.',
    ar: 'صحّح الأرقام اللي فوق عشان تكمّل.',
    area: _area,
    where: _where,
  );

  static const all = [weightInvalid, amountInvalid, fixFigures];
}
