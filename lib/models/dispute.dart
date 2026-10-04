/// Backend spec 014: a problem a customer reports on their order, their request
/// for more time (seller) and the person they named to collect (buyer).
library;

DateTime? _time(Object? raw) => raw == null ? null : DateTime.tryParse('$raw')?.toLocal();

String? _str(Object? raw) => raw == null ? null : '$raw';

/// The reasons the backend accepts (`DisputeReason`), with the order screen's wording.
const disputeReasons = <(String, String)>[
  ('not_as_listed', 'The piece is not what the listing showed'),
  ('disagree_inspection', 'I disagree with the inspection result'),
  ('money_wrong', 'Money is missing or wrong'),
  ('other_side_unresponsive', 'The other side is not responding'),
  ('not_theirs_to_sell', 'I think this piece is not theirs to sell'),
  ('other', 'Something else'),
];

/// Only the buyer may say the piece is not theirs to sell.
const buyerOnlyDisputeReasons = {'not_theirs_to_sell'};

/// The reasons a seller may give for more time (`ExtensionRequestReason`).
const extensionReasons = <(String, String)>[
  ('travelling', "I'm travelling or out of Cairo"),
  ('emergency', 'Health or family emergency'),
  ('branch_closed', 'The branch was closed when I went'),
  ('other', 'Another reason'),
];

String disputeReasonLabel(String code) => disputeReasons.where((r) => r.$1 == code).firstOrNull?.$2 ?? 'Something else';

String extensionReasonLabel(String code) => extensionReasons.where((r) => r.$1 == code).firstOrNull?.$2 ?? 'Another reason';

/// The customer's own dispute ("CustomerDispute"): never the other party's.
class CustomerDispute {
  const CustomerDispute({
    required this.ref,
    required this.reason,
    required this.detail,
    required this.state,
    required this.openedAt,
    this.orderRef,
    this.photoCount = 0,
    this.outcome,
    this.reply,
    this.resolvedAt,
  });

  final String ref;
  final String? orderRef;
  final String reason;
  final String detail;
  final int photoCount;

  /// open, being_looked_at, resolved.
  final String state;

  /// resume, against_sale.
  final String? outcome;

  /// Dahab's answer, once resolved.
  final String? reply;
  final DateTime openedAt;
  final DateTime? resolvedAt;

  bool get resolved => state == 'resolved';

  static CustomerDispute? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return CustomerDispute(
      ref: '${j['ref'] ?? ''}',
      orderRef: _str(j['order_ref']),
      reason: '${j['reason'] ?? 'other'}',
      detail: '${j['detail'] ?? ''}',
      photoCount: (j['photo_count'] as num?)?.toInt() ?? 0,
      state: '${j['state'] ?? 'open'}',
      outcome: _str(j['outcome']),
      reply: _str(j['reply']),
      openedAt: _time(j['opened_at']) ?? DateTime.now(),
      resolvedAt: _time(j['resolved_at']),
    );
  }
}

/// The seller's latest request for more time on an order.
class OrderExtensionRequest {
  const OrderExtensionRequest({required this.state, required this.reason, required this.detail, required this.requestedAt, this.hoursGranted, this.answerNote, this.answeredAt});

  /// waiting, accepted, refused, lapsed.
  final String state;
  final String reason;
  final String detail;
  final int? hoursGranted;
  final String? answerNote;
  final DateTime requestedAt;
  final DateTime? answeredAt;

  static OrderExtensionRequest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return OrderExtensionRequest(
      state: '${j['state'] ?? 'waiting'}',
      reason: '${j['reason'] ?? 'other'}',
      detail: '${j['detail'] ?? ''}',
      hoursGranted: (j['hours_granted'] as num?)?.toInt(),
      answerNote: _str(j['answer_note']),
      requestedAt: _time(j['requested_at']) ?? DateTime.now(),
      answeredAt: _time(j['answered_at']),
    );
  }
}

/// The person the buyer named to collect; the phone comes masked.
class OrderProxy {
  const OrderProxy({required this.name, required this.phoneMasked, this.namedAt});

  final String name;
  final String phoneMasked;
  final DateTime? namedAt;

  static OrderProxy? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return OrderProxy(name: '${raw['name'] ?? ''}', phoneMasked: '${raw['phone_masked'] ?? ''}', namedAt: _time(raw['named_at']));
  }
}
