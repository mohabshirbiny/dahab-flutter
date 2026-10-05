/// Orders and listings are rendered from small content blocks so the mock
/// data can describe every card variant in the prototype without the UI
/// hard-coding each one. A real API would map its order states onto these.
library;

import 'dispute.dart';

enum OrderStage { action, waiting, done }

enum OrderRole { sell, buy }

enum Tone { ok, wait, bad, warn, neutral }

class OrderCardData {
  const OrderCardData({
    required this.id,
    required this.title,
    required this.status,
    required this.statusTone,
    required this.subtitle,
    required this.blocks,
    this.stage = OrderStage.action,
    this.role = OrderRole.sell,
    this.roleIcon,
    this.detailView = 'owner',
    this.pieceId,
  });

  final String id;
  final String title;
  final String status;
  final Tone statusTone;

  /// "You are selling, 12.40 g".
  final String subtitle;

  /// `tag` (selling) or `search` (buying); null hides the icon (listings).
  final String? roleIcon;
  final OrderStage stage;
  final OrderRole role;
  final List<OrderBlock> blocks;

  /// Which variant of the detail screen "See the piece" opens.
  final String detailView;

  /// The piece it opens; null for the prototype's mock cards.
  final String? pieceId;
}

sealed class OrderBlock {
  const OrderBlock();
}

/// A `.soft` panel of key/value rows on paper.
class RowsBlock extends OrderBlock {
  const RowsBlock(this.rows);
  final List<KV> rows;
}

class KV {
  const KV(this.k, this.v, {this.tone = Tone.neutral, this.rule = false});
  final String k;
  final String v;
  final Tone tone;
  final bool rule;
}

/// A `.note` with icon.
class NoteBlock extends OrderBlock {
  const NoteBlock(this.icon, this.text, {this.tone = Tone.wait});
  final String icon;
  final String text;
  final Tone tone;
}

/// A `.track` timeline.
class TrackBlock extends OrderBlock {
  const TrackBlock(this.steps);
  final List<TrackStep> steps;
}

class TrackStep {
  const TrackStep(this.title, this.sub, {this.state = 'todo', this.action, this.gold = false});
  final String title;
  final String sub;

  /// done / now / todo
  final String state;
  final String? action;
  final bool gold;
}

/// A line of `.tiny` text.
class TextBlock extends OrderBlock {
  const TextBlock(this.text, {this.inset = false});
  final String text;

  /// Rendered inside a paper panel (listing review feedback).
  final bool inset;
}

/// The green "+ 24,000 EGP" deposit-returned panel.
class AmountBlock extends OrderBlock {
  const AmountBlock({required this.caption, required this.amount, required this.rows});
  final String caption;
  final String amount;
  final List<KV> rows;
}

/// Buttons. `action` is an id handled by the UI (see OrderActions).
class ActionsBlock extends OrderBlock {
  const ActionsBlock(this.actions);
  final List<OrderAction> actions;
}

class OrderAction {
  const OrderAction(this.label, this.action, {this.primary = false});
  final String label;
  final String action;
  final bool primary;
}

// ---- Orders from the API (backend spec 012, contracts/orders-api.md "CustomerOrder") ----

/// The customer's side of an order.
enum OrderSide { buyer, seller }

/// The customer-facing stage the backend derives from the order's state.
enum CustomerOrderStage { bringPiece, atIgi, decide, pay, collect, done, cancelled, other }

CustomerOrderStage _stageOf(String raw) => switch (raw) {
  'bring_piece' => CustomerOrderStage.bringPiece,
  'at_igi' => CustomerOrderStage.atIgi,
  'decide' => CustomerOrderStage.decide,
  'pay' => CustomerOrderStage.pay,
  'collect' => CustomerOrderStage.collect,
  'done' => CustomerOrderStage.done,
  'cancelled' => CustomerOrderStage.cancelled,
  _ => CustomerOrderStage.other,
};

DateTime? _time(Object? raw) => raw == null ? null : DateTime.tryParse('$raw')?.toLocal();

String? _str(Object? raw) => raw == null ? null : '$raw';

/// The deadline running in the order's state (`reach_branch`, `decision`, `balance`,
/// `collect`, `return`).
class OrderDeadline {
  const OrderDeadline({required this.kind, required this.at, required this.overdue});

  final String kind;
  final DateTime at;
  final bool overdue;

  static OrderDeadline? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = _time(raw['at']);
    return at == null ? null : OrderDeadline(kind: '${raw['kind']}', at: at, overdue: raw['overdue'] == true);
  }
}

/// The latest inspection result: measurements only, plus the new price when the
/// buyer must decide.
class OrderInspection {
  const OrderInspection({
    required this.id,
    required this.outcome,
    this.statedKarat,
    this.measuredKarat,
    this.statedWeight,
    this.measuredWeight,
    this.weightDiffPct,
    this.stoneGrade,
    this.certificateNumber,
    this.note,
    this.inspectedAt,
    this.newPrice,
    this.pricePending = false,
    this.decisionNeeded = false,
  });

  final String id;

  /// pass, weight_adjust, stone_regrade, karat_cancel, fake_cancel.
  final String outcome;
  final int? statedKarat;
  final int? measuredKarat;
  final String? statedWeight;
  final String? measuredWeight;
  final String? weightDiffPct;
  final String? stoneGrade;
  final String? certificateNumber;
  final String? note;
  final DateTime? inspectedAt;
  final String? newPrice;

  /// A lower stone grade waiting for Dahab's price.
  final bool pricePending;
  final bool decisionNeeded;

  static OrderInspection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, dynamic>();
    return OrderInspection(
      id: '${j['inspection_id']}',
      outcome: '${j['outcome']}',
      statedKarat: (j['stated_karat'] as num?)?.toInt(),
      measuredKarat: (j['measured_karat'] as num?)?.toInt(),
      statedWeight: _str(j['stated_weight_g']),
      measuredWeight: _str(j['measured_weight_g']),
      weightDiffPct: _str(j['weight_diff_pct']),
      stoneGrade: _str(j['measured_stone_grade']),
      certificateNumber: _str(j['certificate_number']),
      note: _str(j['inspector_note']),
      inspectedAt: _time(j['inspected_at']),
      newPrice: _str(j['new_price']),
      pricePending: j['price_pending'] == true,
      decisionNeeded: j['decision_needed'] == true,
    );
  }
}

/// The buyer's collection (never on the seller's side).
class OrderCollection {
  const OrderCollection({required this.codeAvailable, this.collectDeadline, this.collectedAt, this.windowPassed = false});

  final bool codeAvailable;
  final DateTime? collectDeadline;
  final DateTime? collectedAt;
  final bool windowPassed;

  static OrderCollection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return OrderCollection(
      codeAvailable: raw['code_available'] == true,
      collectDeadline: _time(raw['collect_deadline']),
      collectedAt: _time(raw['collected_at']),
      windowPassed: raw['window_passed'] == true,
    );
  }
}

/// A piece waiting at the branch for its seller (never on the buyer's side).
class OrderReturn {
  const OrderReturn({required this.returnDeadline, required this.codeAvailable, required this.canRelist, this.collectedAt, this.relistedAt, this.windowPassed = false});

  final DateTime returnDeadline;
  final bool codeAvailable;
  final bool canRelist;
  final DateTime? collectedAt;
  final DateTime? relistedAt;
  final bool windowPassed;

  static OrderReturn? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return OrderReturn(
      returnDeadline: _time(raw['return_deadline']) ?? DateTime.now(),
      codeAvailable: raw['code_available'] == true,
      canRelist: raw['can_relist'] == true,
      collectedAt: _time(raw['collected_at']),
      relistedAt: _time(raw['relisted_at']),
      windowPassed: raw['window_passed'] == true,
    );
  }
}

/// One event of the order's story, oldest first.
class OrderTimelineEvent {
  const OrderTimelineEvent({required this.event, required this.at, this.detail = const {}});

  final String event;
  final DateTime at;
  final Map<String, dynamic> detail;

  static OrderTimelineEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = _time(raw['at']);
    if (at == null) return null;
    return OrderTimelineEvent(event: '${raw['event']}', at: at, detail: (raw['detail'] as Map?)?.cast<String, dynamic>() ?? const {});
  }
}

/// One of the customer's own orders, as the buyer or the seller. The other party
/// appears by display reference only. Money is a 4-place decimal string.
class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.orderRef,
    required this.side,
    required this.state,
    required this.stage,
    required this.listingId,
    required this.category,
    required this.typeNameEn,
    required this.typeNameAr,
    required this.listingState,
    required this.lockedTotalPrice,
    required this.depositAmount,
    this.depositHeld,
    this.invoiceId,
    this.invoiceNumber,
    required this.actions,
    required this.timeline,
    this.karat,
    this.weight,
    this.branchNameEn = '',
    this.branchNameAr = '',
    this.branchAddressEn = '',
    this.counterpartyRef,
    this.deadline,
    this.amountDue,
    this.finalTotal,
    this.sellerProceeds,
    this.inspection,
    this.collection,
    this.sellerReturn,
    this.cancelState,
    this.cancelledAt,
    this.cancelReasonKind,
    this.collectionCode,
    this.returnCode,
    this.frozen = false,
    this.dispute,
    this.disputeOutcome,
    this.extensionRequest,
    this.proxy,
  });

  final String id;
  final String orderRef;
  final OrderSide side;
  final String state;
  final CustomerOrderStage stage;
  final String listingId;
  final String category;
  final String typeNameEn;
  final String typeNameAr;
  final int? karat;
  final String? weight;
  final String listingState;
  final String branchNameEn;
  final String branchNameAr;
  final String branchAddressEn;
  final String? counterpartyRef;
  final String lockedTotalPrice;
  final String depositAmount;

  /// Backend spec 015: what this order holds in the buyer's wallet now (from the
  /// ledger); null for the seller, or from an older backend.
  final String? depositHeld;

  /// Backend spec 016: your own tax invoice once the balance is paid (none for orders paid before it).
  final String? invoiceId;
  final String? invoiceNumber;
  final OrderDeadline? deadline;

  /// The buyer's balance while it is due.
  final String? amountDue;

  /// What the buyer pays in all (buyer only).
  final String? finalTotal;

  /// What the seller was paid (seller only, once paid).
  final String? sellerProceeds;
  final OrderInspection? inspection;
  final OrderCollection? collection;
  final OrderReturn? sellerReturn;
  final String? cancelState;
  final DateTime? cancelledAt;

  /// seller, deadline_missed, staff, no_pay, no_answer, declined, inspection.
  final String? cancelReasonKind;

  /// What the customer may do now: cancel, relist, ask_more_time (seller); decide, pay,
  /// name_proxy (buyer); report_problem (either).
  final List<String> actions;
  final List<OrderTimelineEvent> timeline;

  /// Only in the owner's own detail, never in a list.
  final String? collectionCode;
  final String? returnCode;

  /// Spec 014: on hold while a dispute is open (state `disputed`).
  final bool frozen;

  /// Your own dispute on this order, if you raised one.
  final CustomerDispute? dispute;

  /// resumed or cancelled, once a dispute on the order (either side's) was resolved.
  final String? disputeOutcome;

  /// The seller's latest request for more time (seller only).
  final OrderExtensionRequest? extensionRequest;

  /// The person named to collect (buyer only).
  final OrderProxy? proxy;

  bool get isSeller => side == OrderSide.seller;
  bool can(String action) => actions.contains(action);

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    final piece = (j['piece'] as Map?)?.cast<String, dynamic>() ?? const {};
    final type = (piece['piece_type'] as Map?)?.cast<String, dynamic>() ?? const {};
    final branch = (j['branch'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cancel = (j['cancel'] as Map?)?.cast<String, dynamic>();
    return CustomerOrder(
      id: '${j['id']}',
      orderRef: '${j['order_ref'] ?? ''}',
      side: j['role'] == 'seller' ? OrderSide.seller : OrderSide.buyer,
      state: '${j['state'] ?? ''}',
      stage: _stageOf('${j['stage']}'),
      listingId: '${piece['listing_id'] ?? ''}',
      category: '${piece['category'] ?? 'gold'}',
      typeNameEn: '${type['name_en'] ?? ''}',
      typeNameAr: '${type['name_ar'] ?? ''}',
      karat: (piece['karat'] as num?)?.toInt(),
      weight: _str(piece['weight_g']),
      listingState: '${piece['listing_state'] ?? ''}',
      branchNameEn: '${branch['name_en'] ?? ''}',
      branchNameAr: '${branch['name_ar'] ?? ''}',
      branchAddressEn: '${branch['address_en'] ?? ''}',
      counterpartyRef: _str(j['counterparty_ref']),
      lockedTotalPrice: '${j['locked_total_price'] ?? '0'}',
      depositAmount: '${j['deposit_amount'] ?? '0'}',
      depositHeld: _str(j['deposit_held']),
      invoiceId: _str((j['invoice'] as Map?)?['id']),
      invoiceNumber: _str((j['invoice'] as Map?)?['number']),
      deadline: OrderDeadline.fromJson(j['deadline']),
      amountDue: _str(j['amount_due']),
      finalTotal: _str(j['final_total']),
      sellerProceeds: _str(j['seller_proceeds']),
      inspection: OrderInspection.fromJson(j['inspection']),
      collection: OrderCollection.fromJson(j['collection']),
      sellerReturn: OrderReturn.fromJson(j['seller_return']),
      cancelState: _str(cancel?['state']),
      cancelledAt: _time(cancel?['at']),
      cancelReasonKind: _str(cancel?['reason_kind']),
      actions: [for (final a in (j['actions'] as List? ?? const [])) '$a'],
      timeline: [for (final e in (j['timeline'] as List? ?? const [])) ?OrderTimelineEvent.fromJson(e)],
      collectionCode: _str(j['collection_code']),
      returnCode: _str(j['return_code']),
      frozen: j['frozen'] == true,
      dispute: CustomerDispute.fromJson(j['dispute']),
      disputeOutcome: _str(j['dispute_outcome']),
      extensionRequest: OrderExtensionRequest.fromJson(j['extension_request']),
      proxy: OrderProxy.fromJson(j['proxy']),
    );
  }
}

/// What a 409 `insufficient_funds` on pay-balance says.
class BalanceShortfall {
  const BalanceShortfall({required this.amountDue, required this.available, required this.shortfall});

  final String amountDue;
  final String available;
  final String shortfall;
}
