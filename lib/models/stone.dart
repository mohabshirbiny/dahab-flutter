/// What a stone piece is, as its seller states it, and the certificate it comes with
/// (backend `stone` on the listing, the market piece and the order; null for gold).
library;

class StoneDetails {
  const StoneDetails({this.certificateKind, this.carat, this.clarity, this.cut});

  /// `igi`, `other_lab` or `none`; null for a listing made before it was asked.
  final String? certificateKind;

  /// Carats, 2 decimals (`0.70`).
  final String? carat;

  /// `vvs`, `vs`, `si` or `i`.
  final String? clarity;

  /// `excellent`, `very_good` or `good`.
  final String? cut;

  bool get hasNoCertificate => certificateKind == 'none';
  bool get describesStone => carat != null || clarity != null || cut != null;

  static StoneDetails? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    String? s(String k) => j[k] == null ? null : '${j[k]}';
    return StoneDetails(certificateKind: s('certificate_kind'), carat: s('carat'), clarity: s('clarity'), cut: s('cut'));
  }
}

/// The buyer's code on an order (backend `promo` on the buyer's order): the price before it,
/// the discount and the total, and what it took off the deposit.
class BuyerPromo {
  const BuyerPromo({
    required this.code,
    required this.givesSpread,
    this.priceBefore,
    this.discount,
    this.total,
    this.indicative = false,
    this.depositFull,
    this.depositDiscount,
  });

  final String code;

  /// The code hands the spread back: the buyer pays the price the seller gets.
  final bool givesSpread;
  final String? priceBefore;
  final String? discount;
  final String? total;

  /// Worked out on the stated weight until IGI measures it.
  final bool indicative;
  final String? depositFull;
  final String? depositDiscount;

  bool get hasDiscount => (double.tryParse(discount ?? '') ?? 0) > 0;
  bool get hasDepositDiscount => (double.tryParse(depositDiscount ?? '') ?? 0) > 0;

  static BuyerPromo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    String? s(String k) => j[k] == null ? null : '${j[k]}';
    return BuyerPromo(
      code: '${j['code'] ?? ''}',
      givesSpread: j['gives_spread'] == true,
      priceBefore: s('price_before_egp'),
      discount: s('discount_egp'),
      total: s('total_egp'),
      indicative: j['indicative'] == true,
      depositFull: s('deposit_full_egp'),
      depositDiscount: s('deposit_discount_egp'),
    );
  }
}
