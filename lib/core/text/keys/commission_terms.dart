import '../text_key.dart';

/// The *Dahab commission* card on How prices work. `account.commission.*`. The figures are
/// setting placeholders (`{commission_gold_pct}`, `{commission_stone_pct}`,
/// `{commission_minimum_egp}`), so a changed setting changes the words.
///
/// The Arabic defaults are AR-DRAFT, for the owner's review. Keys are append-only.
abstract final class CommissionTermsKeys {
  static const _area = 'Account';
  static const _where = 'How prices work';

  static const onGold = TextKey(
    'account.commission.on_gold',
    '{commission_gold_pct}% of the making charge',
    ar: '{commission_gold_pct}٪ من المصنعية',
    placeholders: ['commission_gold_pct'],
    area: _area,
    where: _where,
  );
  static const onStones = TextKey(
    'account.commission.on_stones',
    '{commission_stone_pct}% of the full price',
    ar: '{commission_stone_pct}٪ من السعر كله',
    placeholders: ['commission_stone_pct'],
    area: _area,
    where: _where,
  );
  static const minimum = TextKey(
    'account.commission.minimum',
    '{commission_minimum_egp} EGP',
    ar: '{commission_minimum_egp} جنيه',
    placeholders: ['commission_minimum_egp'],
    area: _area,
    where: _where,
  );
  static const note = TextKey(
    'account.commission.note',
    'On gold it comes from the making charge, never from the value of your gold. On a diamond piece, with gold or without, it is {commission_stone_pct}% of the full price.',
    ar: 'على الذهب بتتاخد من المصنعية، ومش بتتاخد أبدا من قيمة ذهبك. على قطعة الألماس، فيها ذهب أو لأ، بتبقى {commission_stone_pct}٪ من السعر كله.',
    placeholders: ['commission_stone_pct'],
    area: _area,
    where: _where,
  );

  static const all = <TextKey>[onGold, onStones, minimum, note];
}
