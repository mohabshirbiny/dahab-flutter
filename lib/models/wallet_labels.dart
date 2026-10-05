/// Customer-facing wording for each ledger event kind (backend spec 008,
/// `ledger_event_kind`). The API sends only the code; these English source
/// strings are translated through the app's dictionary (Arabic in
/// `core/i18n/ar_extra.dart`). A kind the app does not know yet gets [other].
class WalletLabels {
  const WalletLabels(this.label, this.type, this.note);

  /// The row's title ("Added by bank transfer").
  final String label;

  /// The short type on the detail screen ("Top-up").
  final String type;

  /// The plain explanation on the detail screen.
  final String note;

  static const other = WalletLabels('Wallet movement', 'Movement', 'A movement on your wallet.');

  static const byKind = {
    'topup': WalletLabels('Added by bank transfer', 'Top-up', 'Money you sent us, matched and added to your wallet. Dahab takes nothing on top-ups.'),
    'deposit_hold': WalletLabels(
      'Deposit held on a purchase',
      'Hold placed',
      'Set aside as your deposit on a piece you asked to buy. Still yours, just not spendable until the order finishes.',
    ),
    'deposit_release': WalletLabels('Deposit returned', 'Hold released', 'Your deposit came back to your available balance in full.'),
    'deposit_forfeit': WalletLabels('Deposit kept after a missed payment', 'Deposit kept', 'The balance was not paid in time, so the deposit was kept as agreed compensation.'),
    'settlement_seller': WalletLabels('Sale settled', 'Sale settled', 'Settlement for a piece you sold. Commission and VAT were taken before this reached you.'),
    'first_sale_payout': WalletLabels('First sale paid early', 'Paid early', 'Your first gold sale was paid to you before the buyer paid, as a welcome.'),
    'balance_payment': WalletLabels('Balance paid on a purchase', 'Balance paid', 'The rest of the price of a piece you bought.'),
    'withdrawal': WalletLabels('Withdrawn to your bank', 'Withdrawal', 'Sent to your payout account.'),
    // Backend spec 013: the other two steps of a withdrawal (same ledger kind).
    'withdrawal_hold': WalletLabels('Withdrawal requested', 'Withdrawal', 'Set aside for a withdrawal to your bank. It leaves once a person has checked it.'),
    'withdrawal_return': WalletLabels('Withdrawal returned', 'Withdrawal returned', 'The withdrawal did not go ahead, so the money came back to your available balance.'),
    'compensation': WalletLabels('Compensation from Dahab', 'Compensation', 'Paid into your wallet by Dahab.'),
    'weight_adjustment': WalletLabels('Weight adjustment', 'Adjustment', 'A difference after the lab confirmed the weight.'),
    'reversal': WalletLabels('Correction', 'Correction', 'A correction of an earlier movement.'),
    // Backend spec 016: Dahab corrected one of your tax invoices and gave back part of its charge.
    'credit_note': WalletLabels('Invoice correction', 'Credit note', 'Dahab corrected one of your invoices and added the difference to your wallet.'),
  };

  static WalletLabels of(String kind) => byKind[kind] ?? other;
}
