import '../core/utils/format.dart' show dayMonth;
import 'wallet_labels.dart';

enum TxnType { moneyIn, moneyOut, hold }

/// The customer's two figures. Live values come from `GET /customer/me/wallet`
/// (backend spec 008) as 4-place decimal strings; they are parsed for display
/// only — the app never computes money (the total comes from the API).
class WalletSummary {
  const WalletSummary({required this.available, required this.held, num? total, num? heldOnOrders, this.pendingWithdrawals = 0}) : _total = total, _heldOnOrders = heldOnOrders;

  factory WalletSummary.fromJson(Map<String, dynamic> j) => WalletSummary(
    available: _amount(j['available']),
    held: _amount(j['held']),
    total: _amount(j['total']),
    heldOnOrders: j.containsKey('held_on_orders') ? _amount(j['held_on_orders']) : null,
    pendingWithdrawals: _amount(j['pending_withdrawals']),
  );

  static const empty = WalletSummary(available: 0, held: 0, total: 0);

  final num available;
  final num held;
  final num? _total;
  final num? _heldOnOrders;

  /// Backend spec 013: the part of held on its way to the customer's bank
  /// (withdrawals requested or under review).
  final num pendingWithdrawals;
  num get total => _total ?? available + held;

  /// The part of held set aside against open orders.
  num get heldOnOrders => _heldOnOrders ?? held;
}

num _amount(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

/// One buy request or order holding money, from `GET /customer/me/wallet/held`
/// (backend spec 015). The amount is the ledger's; the app adds nothing up.
class HeldItem {
  const HeldItem({required this.type, required this.id, required this.amount, this.ref, this.titleEn, this.titleAr, this.state = ''});

  factory HeldItem.fromJson(Map<String, dynamic> j) => HeldItem(
    type: '${j['type'] ?? 'buy_request'}',
    id: '${j['id'] ?? ''}',
    ref: j['ref'] as String?,
    titleEn: j['title'] as String?,
    titleAr: j['title_ar'] as String?,
    state: '${j['state'] ?? ''}',
    amount: _amount(j['amount']),
  );

  /// `buy_request` or `order`.
  final String type;
  final String id;
  final String? ref;
  final String? titleEn;
  final String? titleAr;
  final String state;
  final num amount;

  bool get isOrder => type == 'order';
}

/// The lines and their total (the wallet's held_on_orders), as the backend sends them.
class HeldItems {
  const HeldItems({required this.total, required this.items});

  factory HeldItems.fromJson(Map<String, dynamic> j) =>
      HeldItems(total: _amount(j['total']), items: [for (final i in (j['items'] as List? ?? const [])) HeldItem.fromJson((i as Map).cast<String, dynamic>())]);

  static const empty = HeldItems(total: 0, items: []);

  final num total;
  final List<HeldItem> items;
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    required String date,
    required this.type,
    required this.label,
    required this.amount,
    required this.reference,
    required this.typeLabel,
    required this.balanceAfter,
    required this.note,
    this.link,
    this.at,
    this.heldAfter,
    num? before,
  }) : _date = date,
       _before = before;

  /// One row of `GET /customer/me/wallet/transactions` (backend spec 008): one
  /// ledger entry, with the change to available (a hold is money out of
  /// available) and both balances after it. Wording comes from [WalletLabels].
  factory WalletTxn.fromJson(Map<String, dynamic> j) {
    final kind = (j['kind'] ?? '') as String;
    final available = _amount(j['available_change']);
    final at = DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal();
    // Backend spec 013: a withdrawal is three entries of one kind — set aside
    // (out of available), sent (out of held) or returned (back to available).
    final withdrawalStep = kind != 'withdrawal' ? null : (available < 0 ? 'withdrawal_hold' : (available > 0 ? 'withdrawal_return' : 'withdrawal'));
    final sent = withdrawalStep == 'withdrawal';
    final change = sent ? _amount(j['held_change']) : available;
    final words = WalletLabels.of(withdrawalStep ?? kind);
    return WalletTxn(
      id: (j['id'] ?? '') as String,
      date: '',
      type: kind == 'deposit_hold' || withdrawalStep == 'withdrawal_hold' ? TxnType.hold : (change >= 0 ? TxnType.moneyIn : TxnType.moneyOut),
      label: words.label,
      amount: change,
      reference: (j['reference'] as String?) ?? '—',
      typeLabel: words.type,
      balanceAfter: _amount(j['available_after']),
      note: words.note,
      at: at,
      heldAfter: _amount(j['held_after']),
      before: sent ? _amount(j['available_after']) : null,
    );
  }

  final String id;

  /// "28 Aug" — live rows in the app's language; mock rows as given.
  final String _date;
  String get date => at == null ? _date : dayMonth(at!);
  final TxnType type;
  final String label;

  /// Change to the available balance (negative for a hold or money out).
  final num amount;
  final String reference;
  final String typeLabel;

  /// Available balance after this movement.
  final num balanceAfter;
  final String note;

  /// Screen id of the related record (`invoice`, `held`). Mock rows only.
  final String? link;

  /// When it happened (live rows).
  final DateTime? at;

  /// Held balance after this movement (live rows).
  final num? heldAfter;

  /// Set when [amount] did not change the available balance (money sent from held).
  final num? _before;

  num get balanceBefore => _before ?? balanceAfter - amount;
}

/// One of Dahab's accounts to send money to (backend spec 009,
/// `GET /customer/me/wallet/topup-methods`). `details` are ordered per method
/// and labelled by the app ([TopUpWords.detailLabel]). The daily limit and the
/// provider fee are for display only: the backend credits what actually arrives.
class ReceivingAccount {
  const ReceivingAccount({required this.id, required this.method, required this.label, required this.details, this.dailyLimit, this.providerFeePercent, this.note});

  factory ReceivingAccount.fromJson(Map<String, dynamic> j) => ReceivingAccount(
    id: (j['id'] as num).toInt(),
    method: (j['method'] ?? '') as String,
    label: (j['label'] ?? '') as String,
    details: [for (final d in (j['details'] as List? ?? const [])) ((d as Map)['key'] as String, '${d['value']}')],
    dailyLimit: j['daily_limit'] == null ? null : _amount(j['daily_limit']),
    providerFeePercent: j['provider_fee_percent'] == null ? null : _amount(j['provider_fee_percent']),
    note: j['note'] as String?,
  );

  final int id;

  /// `bank_transfer` | `instapay` | `vodafone_cash`.
  final String method;
  final String label;

  /// (key, value): `bank_name`, `account_holder`, `account_number`, `iban`,
  /// `instapay_address`, `wallet_number`.
  final List<(String, String)> details;
  final num? dailyLimit;
  final num? providerFeePercent;
  final String? note;
}

/// The customer's reference and the active accounts, grouped by method.
class TopUpMethods {
  const TopUpMethods({required this.reference, required this.methods});

  factory TopUpMethods.fromJson(Map<String, dynamic> j) => TopUpMethods(
    reference: (j['reference'] ?? '') as String,
    methods: [
      for (final m in (j['methods'] as List? ?? const []))
        ((m as Map)['method'] as String, [for (final a in (m['accounts'] as List? ?? const [])) ReceivingAccount.fromJson((a as Map).cast<String, dynamic>())]),
    ],
  );

  /// `DAHAB-<display_ref>`: quoted in the transfer so it is matched quickly.
  final String reference;

  /// (method, its active accounts) in display order; a method with none is left out.
  final List<(String, List<ReceivingAccount>)> methods;
}

/// `pending` | `on_hold` | `credited` | `rejected` | `cancelled`.
enum TopUpStatus {
  pending,
  onHold,
  credited,
  rejected,
  cancelled;

  static TopUpStatus parse(String? v) => switch (v) {
    'on_hold' => onHold,
    'credited' => credited,
    'rejected' => rejected,
    'cancelled' => cancelled,
    _ => pending,
  };
}

/// A transfer notice or a hand credit, as the customer sees it (backend spec 009,
/// `GET /customer/me/wallet/topups`). Staff notes never reach the app.
class TopUp {
  const TopUp({
    required this.id,
    required this.number,
    required this.method,
    required this.reference,
    required this.status,
    required this.claimedAmount,
    this.expectedAmount,
    required this.creditedAmount,
    required this.hasReceipt,
    required this.submittedAt,
    required this.creditedAt,
    required this.rejectReason,
    required this.canCancel,
  });

  factory TopUp.fromJson(Map<String, dynamic> j) => TopUp(
    id: (j['id'] ?? '') as String,
    number: (j['number'] ?? '') as String,
    method: (j['method'] ?? '') as String,
    reference: (j['reference'] ?? '') as String,
    status: TopUpStatus.parse(j['status'] as String?),
    claimedAmount: j['claimed_amount'] == null ? null : _amount(j['claimed_amount']),
    expectedAmount: j['expected_amount'] == null ? null : _amount(j['expected_amount']),
    creditedAmount: j['credited_amount'] == null ? null : _amount(j['credited_amount']),
    hasReceipt: j['has_receipt'] == true,
    submittedAt: DateTime.tryParse('${j['submitted_at'] ?? ''}')?.toLocal(),
    creditedAt: DateTime.tryParse('${j['credited_at'] ?? ''}')?.toLocal(),
    rejectReason: j['reject_reason'] as String?,
    canCancel: j['can_cancel'] == true,
  );

  final String id;

  /// `TOP-128`.
  final String number;
  final String method;
  final String reference;
  final TopUpStatus status;

  /// What the customer said they sent (null for a hand credit).
  final num? claimedAmount;

  /// About what reaches the wallet after the provider's fee (a display-only
  /// estimate from the backend); null with no fee or once the notice is closed.
  final num? expectedAmount;

  /// What actually arrived and was credited.
  final num? creditedAmount;
  final bool hasReceipt;
  final DateTime? submittedAt;
  final DateTime? creditedAt;

  /// `money_not_received` | `duplicate_notice` | `sender_not_accepted` | `other`.
  final String? rejectReason;
  final bool canCancel;

  /// "28 Aug".
  String get date => submittedAt == null ? '' : dayMonth(submittedAt!);
}

class InvoiceSummary {
  const InvoiceSummary({required this.number, required this.sub, required this.kind});

  final String number;

  /// "28 Aug, sold a gold ring, 56,952 EGP"
  final String sub;

  /// sold / bought
  final String kind;
}
