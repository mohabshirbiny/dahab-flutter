import '../text_key.dart';

/// *You need a little more* (2026-11-03): the gold rate may move until a transfer arrives, so the
/// buyer is told to add the deposit plus 1 % of the price. `buy.topup_buffer.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class DepositTopUpKeys {
  static const _area = 'Buying';
  static const _where = 'You need a little more';

  static const suggest = TextKey('buy.topup_buffer.suggest', 'We suggest adding', ar: 'ننصحك تحوّل', area: _area, where: _where);
  static const note = TextKey(
    'buy.topup_buffer.note',
    'The gold price may move until your transfer reaches us. Add a little more (1% of the price) so your wallet still covers the deposit. Anything extra stays in your wallet.',
    ar: 'سعر الدهب ممكن يتغير لحد ما تحويلك يوصلنا. حوّل مبلغ زيادة بسيط (١٪ من سعر القطعة) عشان رصيدك يغطي العربون حتى لو السعر زاد. أي زيادة هتفضل في محفظتك.',
    area: _area,
    where: _where,
  );

  static const all = <TextKey>[suggest, note];
}
