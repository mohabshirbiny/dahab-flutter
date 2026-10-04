/// Payout accounts and withdrawals (backend spec 013). Money stays the API's
/// 4-place decimal string and is parsed for display only.
library;

num _amount(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

DateTime? _at(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();

/// `pending_review` | `active` | `refused` | `removing` (removed ones are not sent).
enum PayoutAccountState { pendingReview, active, refused, removing, removed }

PayoutAccountState _state(String v) => switch (v) {
  'active' => PayoutAccountState.active,
  'refused' => PayoutAccountState.refused,
  'removing' => PayoutAccountState.removing,
  'removed' => PayoutAccountState.removed,
  _ => PayoutAccountState.pendingReview,
};

/// One of the customer's own accounts (`CustomerPayoutAccount`). The number is
/// masked; the refusal note and the checker are never sent.
class PayoutAccount {
  const PayoutAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.numberMasked,
    required this.state,
    required this.inUse,
    required this.canUse,
    required this.canRemove,
    required this.canKeep,
    this.addedAt,
    this.checkedAt,
    this.refusalReason,
  });

  factory PayoutAccount.fromJson(Map<String, dynamic> j) {
    final can = (j['can'] as Map?) ?? const {};
    return PayoutAccount(
      id: '${j['id']}',
      bankName: '${j['bank_name'] ?? ''}',
      accountName: '${j['account_name'] ?? ''}',
      numberMasked: '${j['number_masked'] ?? ''}',
      state: _state('${j['state']}'),
      inUse: j['in_use'] == true,
      addedAt: _at(j['added_at']),
      checkedAt: _at(j['checked_at']),
      refusalReason: j['refusal_reason'] as String?,
      canUse: can['use'] == true,
      canRemove: can['remove'] == true,
      canKeep: can['keep'] == true,
    );
  }

  final String id;
  final String bankName;
  final String accountName;

  /// "•••• 4417"
  final String numberMasked;
  final PayoutAccountState state;

  /// Withdrawals go to this account.
  final bool inUse;
  final DateTime? addedAt;
  final DateTime? checkedAt;

  /// `name_mismatch` | `name_shortened` | `not_in_customer_name` | `details_invalid` | `other`.
  final String? refusalReason;
  final bool canUse;
  final bool canRemove;
  final bool canKeep;

  /// The last four digits of the masked number.
  String get last4 => numberMasked.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

  /// "CIB ••4417" — Your details.
  String get short => '$bankName ••$last4';
}

/// One line of "Recent changes".
class PayoutChange {
  const PayoutChange({required this.kind, required this.bankName, required this.numberMasked, required this.byYou, this.at});

  factory PayoutChange.fromJson(Map<String, dynamic> j) {
    final a = (j['account'] as Map?) ?? const {};
    return PayoutChange(kind: '${j['kind'] ?? ''}', bankName: '${a['bank_name'] ?? ''}', numberMasked: '${a['number_masked'] ?? ''}', at: _at(j['at']), byYou: j['by'] == 'you');
  }

  /// `added` | `verified` | `refused` | `in_use` | `removal_scheduled` | `kept` | `removed` | `request_cancelled`.
  final String kind;
  final String bankName;
  final String numberMasked;
  final DateTime? at;
  final bool byYou;
}

/// `GET /customer/me/payout-accounts`: the accounts (the one in use first),
/// the withdrawal pause and the last 20 changes.
class PayoutView {
  const PayoutView({required this.accounts, required this.changes, this.pauseUntil});

  factory PayoutView.fromJson(Map<String, dynamic> j) => PayoutView(
    accounts: [for (final a in (j['accounts'] as List? ?? const [])) PayoutAccount.fromJson((a as Map).cast<String, dynamic>())],
    pauseUntil: _at((j['pause'] as Map?)?['until']),
    changes: [for (final c in (j['recent_changes'] as List? ?? const [])) PayoutChange.fromJson((c as Map).cast<String, dynamic>())],
  );

  static const empty = PayoutView(accounts: [], changes: []);

  final List<PayoutAccount> accounts;
  final List<PayoutChange> changes;

  /// New withdrawals are refused until then.
  final DateTime? pauseUntil;

  PayoutAccount? get inUse {
    for (final a in accounts) {
      if (a.inUse) return a;
    }
    return null;
  }

  bool get paused => pauseUntil != null && pauseUntil!.isAfter(DateTime.now());
}

/// `requested` | `under_review` | `released` | `rejected` | `cancelled`.
class CustomerWithdrawal {
  const CustomerWithdrawal({
    required this.id,
    required this.number,
    required this.amount,
    required this.state,
    required this.onHold,
    required this.bankName,
    required this.numberMasked,
    required this.cancelledByChange,
    required this.canCancel,
    this.holdMessage,
    this.requestedAt,
    this.releasedAt,
    this.rejectionReason,
  });

  factory CustomerWithdrawal.fromJson(Map<String, dynamic> j) {
    final a = (j['account'] as Map?) ?? const {};
    return CustomerWithdrawal(
      id: '${j['id']}',
      number: '${j['number'] ?? ''}',
      amount: _amount(j['amount']),
      state: '${j['state'] ?? ''}',
      onHold: j['on_hold'] == true,
      holdMessage: j['hold_message'] as String?,
      bankName: '${a['bank_name'] ?? ''}',
      numberMasked: '${a['number_masked'] ?? ''}',
      requestedAt: _at(j['requested_at']),
      releasedAt: _at(j['released_at']),
      rejectionReason: j['rejection_reason'] as String?,
      cancelledByChange: j['cancelled_by_change'] == true,
      canCancel: j['can_cancel'] == true,
    );
  }

  final String id;

  /// "WD-12"
  final String number;
  final num amount;
  final String state;
  final bool onHold;

  /// What Dahab asked, while on hold.
  final String? holdMessage;
  final String bankName;
  final String numberMasked;
  final DateTime? requestedAt;
  final DateTime? releasedAt;
  final String? rejectionReason;
  final bool cancelledByChange;
  final bool canCancel;

  bool get open => state == 'requested' || state == 'under_review';
}

/// The email second-check (`WithdrawalConfirmation`): `sent` → `confirmed` → `used`,
/// or `expired` / `replaced`.
class WithdrawalConfirmation {
  const WithdrawalConfirmation({required this.id, required this.state, required this.amount, required this.accountId, this.expiresAt, this.emailMasked});

  factory WithdrawalConfirmation.fromJson(Map<String, dynamic> j) => WithdrawalConfirmation(
    id: '${j['id']}',
    state: '${j['state'] ?? ''}',
    amount: '${j['amount'] ?? ''}',
    accountId: '${(j['account'] as Map?)?['id'] ?? ''}',
    expiresAt: _at(j['expires_at']),
    emailMasked: j['email_masked'] as String?,
  );

  final String id;
  final String state;

  /// The decimal string the link was sent for.
  final String amount;
  final String accountId;
  final DateTime? expiresAt;

  /// Only when the link was just sent ("m•••@email.com").
  final String? emailMasked;
}

/// What the email link confirms (`/withdrawal-confirmations/read|confirm`), no sign-in.
class LinkConfirmation {
  const LinkConfirmation({required this.state, required this.amount, required this.accountMasked, this.expiresAt});

  factory LinkConfirmation.fromJson(Map<String, dynamic> j) =>
      LinkConfirmation(state: '${j['state'] ?? ''}', amount: _amount(j['amount']), accountMasked: '${j['account_masked'] ?? ''}', expiresAt: _at(j['expires_at']));

  final String state;
  final num amount;

  /// "CIB ••4417"
  final String accountMasked;
  final DateTime? expiresAt;
}

/// Plain words for the codes the API sends (translated through the app's dictionary).
abstract final class PayoutWords {
  static String refusal(String? code) => switch (code) {
    'name_mismatch' => 'The name does not match your ID.',
    'name_shortened' => 'The name is shortened. Use your full name as written on your ID.',
    'not_in_customer_name' => 'The account is not in your name.',
    'details_invalid' => 'The account details look wrong.',
    _ => 'We could not accept this account.',
  };

  static String change(String kind) => switch (kind) {
    'added' => 'New account added',
    'verified' => 'Name checked against your ID',
    'refused' => 'Account refused',
    'in_use' => 'Payout account changed',
    'removal_scheduled' => 'Removal scheduled',
    'kept' => 'Removal cancelled',
    'removed' => 'Account removed',
    'request_cancelled' => 'Request cancelled',
    _ => 'Account updated',
  };

  static String withdrawalState(CustomerWithdrawal w) {
    if (w.onHold) return 'On hold';
    return switch (w.state) {
      'requested' => 'Waiting for review',
      'under_review' => 'Being checked',
      'released' => 'Sent to your bank',
      'rejected' => 'Not sent',
      'cancelled' => 'Cancelled',
      _ => w.state,
    };
  }

  static String rejection(String? code) => switch (code) {
    'account_not_in_name' => 'The account is not in your name.',
    'money_in_straight_out' => 'Money came in and went straight out without trading.',
    'identity_unconfirmed' => 'We could not confirm your identity.',
    'customer_request' => 'You asked us to stop it.',
    _ => 'We could not send it.',
  };
}
