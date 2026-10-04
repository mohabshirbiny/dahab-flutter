/// Buy requests, as the backend sends them (spec 011, `/customer/me/buy-requests*`
/// and the seller's `/customer/me/listings/{id}/buy-requests`). Money is kept as the
/// backend's decimal strings; the app formats it and never computes with it.
library;

/// A `buy_request_state` value. Anything new is kept as [other].
enum BuyRequestState {
  queued,
  accepted,
  releasedNotChosen,
  releasedDeclined,
  releasedExpired,
  withdrawnByBuyer,
  other;

  static BuyRequestState parse(String? value) => switch (value) {
    'queued' => queued,
    'accepted' => accepted,
    'released_not_chosen' => releasedNotChosen,
    'released_declined' => releasedDeclined,
    'released_expired' => releasedExpired,
    'withdrawn_by_buyer' => withdrawnByBuyer,
    _ => other,
  };

  /// The deposit is back in the wallet.
  bool get refunded => this == releasedNotChosen || this == releasedDeclined || this == releasedExpired || this == withdrawnByBuyer;
}

/// The order a request became when the seller accepted it. `cancelled_staff`
/// when Dahab cancelled the sale (the deposit is then back in the wallet).
class OrderSummary {
  const OrderSummary({
    required this.orderRef,
    required this.state,
    required this.branchNameEn,
    required this.branchNameAr,
    required this.acceptedAt,
    required this.reachBranchDeadline,
    required this.lockedTotalPrice,
    this.cancelledAt,
    this.cancelReason,
  });

  final String orderRef;
  final String state;
  final String branchNameEn;
  final String branchNameAr;
  final DateTime acceptedAt;
  final DateTime reachBranchDeadline;
  final String lockedTotalPrice;
  final DateTime? cancelledAt;
  final String? cancelReason;

  bool get cancelled => state == 'cancelled_staff';

  static OrderSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    final branch = (j['branch'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OrderSummary(
      orderRef: '${j['order_ref'] ?? ''}',
      state: '${j['state'] ?? ''}',
      branchNameEn: '${branch['name_en'] ?? ''}',
      branchNameAr: '${branch['name_ar'] ?? ''}',
      acceptedAt: DateTime.tryParse('${j['accepted_at']}')?.toLocal() ?? DateTime.now(),
      reachBranchDeadline: DateTime.tryParse('${j['reach_branch_deadline']}')?.toLocal() ?? DateTime.now(),
      lockedTotalPrice: '${j['locked_total_price'] ?? '0'}',
      cancelledAt: j['cancelled_at'] == null ? null : DateTime.tryParse('${j['cancelled_at']}')?.toLocal(),
      cancelReason: j['cancel_reason'] as String?,
    );
  }
}

/// One of the buyer's own requests. Never names the seller.
class BuyRequest {
  const BuyRequest({
    required this.id,
    required this.state,
    required this.listingId,
    required this.pieceTitleEn,
    required this.pieceTitleAr,
    required this.karat,
    required this.weight,
    required this.listingState,
    required this.queueCount,
    required this.placeInLine,
    required this.aheadCount,
    required this.lockedTotalPrice,
    required this.depositAmount,
    required this.requestedAt,
    required this.sellerReplyDeadline,
    required this.resolvedAt,
    required this.notifyWhenFree,
    required this.order,
  });

  final String id;
  final BuyRequestState state;
  final String listingId;
  final String pieceTitleEn;
  final String pieceTitleAr;
  final int? karat;
  final String? weight;
  final String listingState;
  final int queueCount;

  /// 1 = the seller answers you next. Null unless queued.
  final int? placeInLine;
  final int? aheadCount;
  final String lockedTotalPrice;
  final String depositAmount;
  final DateTime requestedAt;
  final DateTime sellerReplyDeadline;
  final DateTime? resolvedAt;
  final bool notifyWhenFree;
  final OrderSummary? order;

  factory BuyRequest.fromJson(Map<String, dynamic> j) {
    final listing = (j['listing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final type = (listing['piece_type'] as Map?)?.cast<String, dynamic>() ?? const {};
    final karat = (listing['karat'] as num?)?.toInt();
    final nameEn = '${type['name_en'] ?? 'Piece'}';
    final nameAr = '${type['name_ar'] ?? nameEn}';
    return BuyRequest(
      id: '${j['id']}',
      state: BuyRequestState.parse(j['state'] as String?),
      listingId: '${listing['id'] ?? ''}',
      pieceTitleEn: karat == null ? nameEn : '$nameEn, ${karat}K',
      pieceTitleAr: karat == null ? nameAr : '$nameAr، $karat',
      karat: karat,
      weight: listing['weight_g'] as String?,
      listingState: '${listing['state'] ?? ''}',
      queueCount: (listing['queue_count'] as num?)?.toInt() ?? 0,
      placeInLine: (j['place_in_line'] as num?)?.toInt(),
      aheadCount: (j['ahead_count'] as num?)?.toInt(),
      lockedTotalPrice: '${j['locked_total_price'] ?? '0'}',
      depositAmount: '${j['deposit_amount'] ?? '0'}',
      requestedAt: DateTime.tryParse('${j['requested_at']}')?.toLocal() ?? DateTime.now(),
      sellerReplyDeadline: DateTime.tryParse('${j['seller_reply_deadline']}')?.toLocal() ?? DateTime.now(),
      resolvedAt: j['resolved_at'] == null ? null : DateTime.tryParse('${j['resolved_at']}')?.toLocal(),
      notifyWhenFree: j['notify_when_free'] == true,
      order: OrderSummary.fromJson(j['order']),
    );
  }
}

/// One buyer in the line on the seller's own listing: a display reference only.
class SellerQueueItem {
  const SellerQueueItem({
    required this.id,
    required this.placeInLine,
    required this.isHead,
    required this.buyerRef,
    required this.lockedTotalPrice,
    required this.sellerReplyDeadline,
  });

  final String id;
  final int placeInLine;
  final bool isHead;
  final String buyerRef;
  final String lockedTotalPrice;
  final DateTime sellerReplyDeadline;

  factory SellerQueueItem.fromJson(Map<String, dynamic> j) => SellerQueueItem(
    id: '${j['id']}',
    placeInLine: (j['place_in_line'] as num?)?.toInt() ?? 0,
    isHead: j['is_head'] == true,
    buyerRef: '${(j['buyer'] as Map?)?['display_ref'] ?? ''}',
    lockedTotalPrice: '${j['locked_total_price'] ?? '0'}',
    sellerReplyDeadline: DateTime.tryParse('${j['seller_reply_deadline']}')?.toLocal() ?? DateTime.now(),
  );
}

/// The line on the seller's listing and what they would receive if it sold now.
class SellerQueue {
  const SellerQueue({required this.items, required this.youWouldReceive});

  final List<SellerQueueItem> items;
  final String? youWouldReceive;

  SellerQueueItem? get head => items.where((i) => i.isHead).firstOrNull;
}

/// The figures behind "You need a little more" (409 insufficient_funds details).
class DepositShortfall {
  const DepositShortfall({required this.depositAmount, required this.available, required this.shortfall});

  final String depositAmount;
  final String available;
  final String shortfall;
}

/// The deposit terms the buyer accepts with each request (`deposit_agreement`).
class DepositTerms {
  const DepositTerms({required this.id, required this.bodyEn, required this.bodyAr});

  final int id;
  final String bodyEn;
  final String bodyAr;
}
