/// Codes on the sell form and the first-sale advance (backend spec 023). Money is kept as the
/// backend's decimal strings; the app formats them and never computes the commission itself.
library;

/// Whether the first gold sale would be paid ahead (`pays_advance`): the seller's own code or a staff
/// enablement opens it; the backend says whether it is available now and, when not, why.
class PaysAdvance {
  const PaysAdvance({required this.available, required this.capEgp, this.reason});

  final bool available;
  final String capEgp;

  /// `switch_off`, `ceiling`, `not_first_gold`, `not_gold` or `seller_not_eligible`.
  final String? reason;

  static PaysAdvance? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return PaysAdvance(available: j['available'] == true, capEgp: '${j['cap_egp'] ?? '0'}', reason: j['reason'] as String?);
  }
}

/// What a code would do (`POST /customer/me/commission-preview`). Nothing is recorded by asking.
class PromoPreview {
  const PromoPreview({
    required this.code,
    required this.kind,
    required this.mode,
    required this.percent,
    required this.ordinaryEgp,
    required this.chargedEgp,
    required this.savedEgp,
    required this.minimumEgp,
    required this.floorApplied,
    required this.withoutPromoEgp,
    required this.withPromoEgp,
    required this.paysAdvance,
    required this.hasWaiver,
    this.firstSaleOnly = false,
  });

  /// The code as the backend knows it; null when only the seller's credit pool was shown.
  final String? code;

  /// `market_maker`, `first_sale`, `discount` or `referral`.
  final String? kind;

  /// `waive`, `percent` or `none`.
  final String? mode;
  final String? percent;
  final String ordinaryEgp;
  final String chargedEgp;
  final String savedEgp;
  final String minimumEgp;

  /// The minimum commission limited the saving.
  final bool floorApplied;
  final String withoutPromoEgp;
  final String withPromoEgp;
  final PaysAdvance? paysAdvance;

  /// A waiver (this code or a credit in the seller's pool) lowers the commission now.
  final bool hasWaiver;

  /// The code is for a seller's first sale only.
  final bool firstSaleOnly;

  factory PromoPreview.fromJson(Map<String, dynamic> j) {
    final code = (j['code'] as Map?)?.cast<String, dynamic>();
    final commission = (j['commission'] as Map?)?.cast<String, dynamic>() ?? const {};
    final receive = (j['you_receive'] as Map?)?.cast<String, dynamic>() ?? const {};
    final codeCommission = (code?['commission'] as Map?)?.cast<String, dynamic>();
    final waiver = (j['waiver'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PromoPreview(
      code: code?['value'] as String?,
      kind: code?['kind'] as String?,
      mode: codeCommission?['mode'] as String?,
      percent: codeCommission?['percent'] as String?,
      ordinaryEgp: '${commission['ordinary_egp'] ?? '0'}',
      chargedEgp: '${commission['charged_egp'] ?? '0'}',
      savedEgp: '${commission['saved_egp'] ?? '0'}',
      minimumEgp: '${commission['minimum_egp'] ?? '0'}',
      floorApplied: commission['floor_applied'] == true,
      withoutPromoEgp: '${receive['without_promo_egp'] ?? '0'}',
      withPromoEgp: '${receive['with_promo_egp'] ?? '0'}',
      paysAdvance: PaysAdvance.fromJson(j['pays_advance']),
      hasWaiver: waiver['kind'] == 'credit',
      firstSaleOnly: code?['first_sale_only'] == true,
    );
  }

  double get saved => double.tryParse(savedEgp) ?? 0;
}

/// The code recorded on one of the seller's listings (`promo` on the listing).
class ListingPromo {
  const ListingPromo({required this.code, required this.kind, required this.status, required this.canChange, required this.paysAdvance});

  final String code;
  final String kind;

  /// `active`, `spent` or `voided`.
  final String status;
  final bool canChange;
  final bool paysAdvance;

  static ListingPromo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return ListingPromo(
      code: '${j['code'] ?? ''}',
      kind: '${j['kind'] ?? ''}',
      status: '${j['status'] ?? 'active'}',
      canChange: j['can_change'] != false,
      paysAdvance: j['pays_advance'] == true,
    );
  }
}

/// The advance paid on the seller's order (`advance` on the order).
class OrderAdvance {
  const OrderAdvance({required this.amountEgp, required this.status, required this.paidAt, this.recoveredEgp, this.shortfallEgp});

  final String amountEgp;

  /// `outstanding`, `recovered` or `kept` (a written-off advance is never shown as a loss).
  final String status;
  final DateTime? paidAt;
  final String? recoveredEgp;
  final String? shortfallEgp;

  static OrderAdvance? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return OrderAdvance(
      amountEgp: '${j['amount_egp'] ?? '0'}',
      status: '${j['status'] ?? 'outstanding'}',
      paidAt: j['paid_at'] == null ? null : DateTime.tryParse('${j['paid_at']}')?.toLocal(),
      recoveredEgp: j['recovered_egp'] as String?,
      shortfallEgp: j['shortfall_egp'] as String?,
    );
  }
}

/// What a waiver took off the seller's commission on a settled order (`commission` on the order).
class OrderCommission {
  const OrderCommission({required this.recorded, this.ordinaryEgp, this.chargedEgp, this.savedEgp, this.waiver, this.code});

  final bool recorded;
  final String? ordinaryEgp;
  final String? chargedEgp;
  final String? savedEgp;

  /// `none`, `free_relist`, `market_maker` or `credit`.
  final String? waiver;
  final String? code;

  double get saved => double.tryParse(savedEgp ?? '') ?? 0;

  static OrderCommission? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return OrderCommission(
      recorded: j['recorded'] == true,
      ordinaryEgp: j['ordinary_egp'] as String?,
      chargedEgp: j['charged_egp'] as String?,
      savedEgp: j['saved_egp'] as String?,
      waiver: j['waiver'] as String?,
      code: j['code'] as String?,
    );
  }
}
