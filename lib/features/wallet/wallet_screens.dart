import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/payout.dart';
import '../../models/topup_words.dart';
import '../../models/wallet.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_messages.dart';
import '../../services/repositories.dart';
import '../../services/payout_controller.dart';
import '../../services/text_download.dart';
import '../../widgets/widgets.dart';
import '../account/bank_screens.dart' show payoutErrorMessage, pauseLine;

void _download(BuildContext context, String name, String text) => showToast(context, downloadText(name, text) ? 'Downloaded.' : 'Download not available here.');

/// Balance card shared by Account and Wallet.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.summary, this.onOpen, this.showHint = false, this.heldTappable = false});

  final WalletSummary summary;
  final VoidCallback? onOpen;
  final bool showHint;
  final bool heldTappable;

  @override
  Widget build(BuildContext context) {
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const T('Available to use', style: DText.tiny),
                  const Gap(3),
                  T(money(summary.available), style: DText.big),
                ],
              ),
            ),
            if (onOpen != null) const DIcon('chevron-right', size: 16, color: DColors.ink3),
          ],
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DColors.line)),
          ),
          child: DRow(
            'Held on open orders',
            money(summary.heldOnOrders),
            onTap: heldTappable ? () => context.nav(R.held) : null,
            valueWidget: heldTappable
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: T(money(summary.heldOnOrders), style: DText.body13)),
                      const SizedBox(width: 4),
                      const DIcon('chevron-right', size: 14, color: DColors.ink3),
                    ],
                  )
                : null,
          ),
        ),
        // Backend spec 013: withdrawals requested or under review.
        if (summary.pendingWithdrawals > 0) DRow('On its way to your bank', money(summary.pendingWithdrawals)),
        DRow('Total in your wallet', money(summary.total), bold: true, keyIsLabel: false, padding: const EdgeInsets.only(top: 2, bottom: 4)),
        if (showHint) ...[const Gap(5), const T('Tap to see every movement and your statement', style: DText.linkTiny)],
      ],
    );
    return DCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Tappable(onTap: onOpen, child: top),
          const Gap(13),
          DActsRow(
            children: [
              DButton('Withdraw', small: true, onTap: () => context.nav(R.withdraw)),
              DButton.ghost('Add funds', small: true, onTap: () => context.nav(R.addfunds)),
            ],
          ),
        ],
      ),
    );
  }
}

/// `#s-wallet`
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  TxnType? _filter;
  int _reload = 0;
  String? _cancelling;

  /// One key per withdrawal: a retried cancel replays the first answer.
  final _cancelKeys = <String, String>{};

  Future<void> _cancel(CustomerWithdrawal w) async {
    final ok = await ask(
      context,
      title: 'Cancel this withdrawal',
      body: '${w.number}: ${money(w.amount)}. ${context.tr('The money comes back to your available balance.')}',
      yes: 'Cancel the withdrawal',
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = w.id);
    try {
      await context.read<PayoutRepository>().cancel(w.id, idempotencyKey: _cancelKeys.putIfAbsent(w.id, newIdempotencyKey));
      if (mounted) showToast(context, 'Cancelled. The money is back in your wallet.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, payoutErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = null;
          _reload++;
        });
      }
    }
  }

  String _statement(WalletSummary s, List<WalletTxn> txns) {
    String pad(String v, int n) => v.length >= n ? v : v + ' ' * (n - v.length);
    return [
      'DAHAB - WALLET STATEMENT',
      'Mona Hassan Ibrahim',
      '',
      'Available   ${money(s.available)}',
      'Held        ${money(s.heldOnOrders)}',
      if (s.pendingWithdrawals > 0) 'To bank     ${money(s.pendingWithdrawals)}',
      'Total       ${money(s.total)}',
      '',
      for (final x in txns) '${pad(x.date, 12)}${pad(x.label, 35)}${signedMoney(x.amount).padLeft(18)}  bal ${amount(x.balanceAfter)}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<WalletRepository>();
    final payouts = context.read<PayoutRepository>();
    // Backend spec 008: an unverified customer has no wallet use yet.
    final me = context.watch<AuthController>().customer;
    final unverified = me != null && !me.isVerified && me.status != 'suspended';
    return AppPage(
      id: R.wallet,
      child: AsyncView<(WalletSummary, List<WalletTxn>, List<CustomerWithdrawal>)>(
        key: ValueKey(_reload),
        load: () async => (await repo.summary(), await repo.transactions(), await payouts.withdrawals()),
        loadingHeight: 300,
        builder: (context, data) {
          final (summary, txns, withdrawals) = data;
          final rows = _filter == null ? txns : txns.where((t) => t.type == _filter).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unverified) ...[
                DNote(
                  icon: 'alert-triangle',
                  kind: NoteKind.wait,
                  text: authErrorMessage(const ApiException(status: 403, code: 'verification_required', message: '')),
                ),
                const Gap(12),
              ],
              BalanceCard(summary: summary, heldTappable: true),
              const Gap(12),
              const DNote(icon: 'lock', text: 'Held money is set aside for orders you have open. It comes back to available if an order is cancelled.'),
              const Gap(10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DLink('Your top-ups', onTap: () => context.nav(R.topups)),
              ),
              if (withdrawals.isNotEmpty) ...[
                const Gap(14),
                const DLabel('Your withdrawals'),
                for (final w in withdrawals.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WithdrawalCard(w: w, busy: _cancelling == w.id, onCancel: () => _cancel(w)),
                  ),
              ],
              const Gap(14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(child: T('Statement', style: DText.label)),
                  DLink('Download', onTap: () => _download(context, 'dahab-statement.txt', _statement(summary, txns))),
                ],
              ),
              const Gap(9),
              DChips(
                children: [
                  for (final (t, label) in const [(null, 'All'), (TxnType.moneyIn, 'Money in'), (TxnType.moneyOut, 'Money out'), (TxnType.hold, 'Holds')])
                    DChip(label, on: _filter == t, onTap: () => setState(() => _filter = t)),
                ],
              ),
              const Gap(12),
              if (rows.isEmpty)
                DCard(
                  padding: const EdgeInsets.all(22),
                  child: Center(child: T(txns.isEmpty ? 'No movements yet.' : 'No movements of this kind.', style: DText.tiny)),
                )
              else
                DMenuCard(
                  children: [
                    for (final x in rows)
                      DMenu(
                        title: x.label,
                        sub: '${x.date}, balance ${amount(x.balanceAfter)} EGP',
                        trailing: T(
                          signedMoney(x.amount),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: x.type == TxnType.hold ? DColors.wait : (x.amount > 0 ? DColors.ok : DColors.ink2)),
                        ),
                        onTap: () => context.nav(R.txn, query: {'id': x.id}),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// `#s-held` — what is held and why, from the backend's figures only (spec 008 / 013): the part set aside
/// against orders and buy requests, and each withdrawal on its way to the bank. The backend does not
/// send a per-order held amount, so the orders themselves are one tap away instead of re-worked here.
class HeldScreen extends StatelessWidget {
  const HeldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.read<WalletRepository>();
    final payouts = context.read<PayoutRepository>();
    return AppPage(
      id: R.held,
      child: AsyncView<(WalletSummary, List<CustomerWithdrawal>)>(
        load: () async => (await wallet.summary(), await payouts.withdrawals()),
        loadingHeight: 300,
        builder: (context, data) {
          final (summary, withdrawals) = data;
          final onTheWay = [for (final w in withdrawals) if (w.open) w];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Held on open orders', style: DText.tiny),
                    const Gap(3),
                    T(money(summary.heldOnOrders), style: DText.big),
                    const Gap(6),
                    const T('Deposits on pieces you are buying. Each comes back in full if the sale does not go ahead, or goes towards the price when you pay the balance.', style: DText.tiny),
                    const Gap(11),
                    DButton.ghost('See your orders', small: true, onTap: () => context.nav(R.orders)),
                  ],
                ),
              ),
              if (summary.pendingWithdrawals > 0 || onTheWay.isNotEmpty) ...[
                const Gap(14),
                const DLabel('On its way to your bank'),
                DSoft.bordered(
                  child: Column(children: [
                    for (final w in onTheWay) DRow('${w.number} · ${w.bankName} ${w.numberMasked}', money(w.amount)),
                    DRow('In all', money(summary.pendingWithdrawals), rule: onTheWay.isNotEmpty, bold: true),
                  ]),
                ),
              ],
              if (summary.held == 0) ...[
                const Gap(14),
                const DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'Nothing is held right now. All your money is available.'),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// `#s-txn` — one statement line in detail.
class TxnScreen extends StatelessWidget {
  const TxnScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.txn,
      child: AsyncView<List<WalletTxn>>(
        load: context.read<WalletRepository>().transactions,
        builder: (context, all) {
          if (all.isEmpty) {
            return const DCard(
              padding: EdgeInsets.all(22),
              child: Center(child: T('No movements yet.', style: DText.tiny)),
            );
          }
          final x = all.firstWhere((t) => t.id == id, orElse: () => all.first);
          final color = x.type == TxnType.hold ? DColors.wait : (x.amount > 0 ? DColors.ok : DColors.ink);
          return Column(
            children: [
              DCard(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      T(x.label, style: DText.tiny),
                      const Gap(5),
                      T(signedMoney(x.amount), style: DText.big.copyWith(color: color)),
                      const Gap(5),
                      T(x.at == null ? '${x.date} 2026' : '${x.date} ${x.at!.year}', style: DText.tiny),
                    ],
                  ),
                ),
              ),
              const Gap(14),
              DSoft.bordered(
                child: Column(
                  children: [
                    DRow('Reference', x.reference),
                    DRow('Type', x.typeLabel),
                    DRow('Balance before', money(x.balanceBefore)),
                    DRow('Balance after', money(x.balanceAfter), rule: true),
                  ],
                ),
              ),
              const Gap(14),
              DNote(icon: 'info-circle', text: x.note),
              if (x.link != null) ...[const Gap(14), DButton.ghost(x.link == 'invoice' ? 'Open the invoice' : 'See what is held', onTap: () => context.nav(x.link!))],
            ],
          );
        },
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.w, required this.busy, required this.onCancel});

  final CustomerWithdrawal w;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final kind = w.onHold
        ? PillKind.warn
        : switch (w.state) {
            'released' => PillKind.ok,
            'rejected' => PillKind.bad,
            _ => PillKind.wait,
          };
    final detail = w.onHold
        ? (w.holdMessage ?? '')
        : switch (w.state) {
            'rejected' => context.t(PayoutWords.rejection(w.rejectionReason)),
            'cancelled' => context.t(
              w.cancelledByChange ? 'Cancelled because your payout account changed. The money is back in your wallet.' : 'Cancelled. The money is back in your wallet.',
            ),
            'released' => context.t('Sent. It reaches your bank within one working day.'),
            _ => context.t('A person checks every withdrawal before it leaves.'),
          };
    return DCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${money(w.amount)} · ${w.number}', style: DText.body14),
                    Text('${w.bankName} ${w.numberMasked}${w.requestedAt == null ? '' : ' · ${whenOf(w.requestedAt!)}'}', style: DText.tiny),
                  ],
                ),
              ),
              DPill(PayoutWords.withdrawalState(w), kind: kind),
            ],
          ),
          if (detail.isNotEmpty) ...[const Gap(8), Text(detail, style: DText.tiny)],
          if (w.canCancel) ...[const Gap(9), DButton.ghost('Cancel the withdrawal', small: true, loading: busy, onTap: onCancel)],
        ],
      ),
    );
  }
}

/// `#s-withdraw`
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

/// Live (backend spec 013): the available balance, the account in use, the
/// email second-check (Send the link -> Waiting, polled every 5 s -> Confirmed)
/// and the request. A person checks every withdrawal before it leaves.
class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amount = TextEditingController();
  WalletSummary? _summary;
  Object? _loadError;
  WithdrawalConfirmation? _conf;
  Timer? _poll;
  String? _error;
  bool _sending = false;
  bool _busy = false;

  /// One key per request content: a retry of the same request reuses it.
  (String, String)? _sendKey;
  (String, String)? _submitKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    final payouts = context.read<PayoutController>();
    final wallet = context.read<WalletRepository>();
    try {
      final summary = await wallet.summary();
      await payouts.load();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        if (_amount.text.isEmpty && summary.available > 0) _amount.text = group(summary.available.floor());
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  static String _keyFor((String, String)? held, String payload, void Function((String, String)) keep) {
    if (held != null && held.$1 == payload) return held.$2;
    final next = (payload, newIdempotencyKey());
    keep(next);
    return next.$2;
  }

  /// The amount as the API takes it ("42000" or "42000.5"), or null when not valid.
  String? get _amountValue {
    final v = _amount.text.replaceAll(',', '').trim();
    final ok = RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(v) && parseAmount(v) > 0;
    return ok ? v : null;
  }

  /// A confirmation counts only for the amount and account it was sent for.
  static bool _matches(WithdrawalConfirmation c, String amount, String accountId) => c.accountId == accountId && parseAmount(c.amount) == parseAmount(amount);

  void _onAmountChanged() {
    final c = _conf;
    final v = _amountValue;
    setState(() {
      _error = null;
      if (c != null && (v == null || parseAmount(c.amount) != parseAmount(v))) {
        _conf = null;
        _poll?.cancel();
      }
    });
  }

  void _setAmount(String text) {
    _amount.text = text;
    _onAmountChanged();
  }

  String? _check(PayoutAccount? account) {
    final s = _summary;
    final v = _amountValue;
    if (account == null) return context.tr('Add a payout account first.');
    if (v == null) return context.tr('Enter an amount above 0, e.g. 10,000.');
    if (s != null && parseAmount(v) > s.available) return '${context.tr('Enter an amount up to')} ${money(s.available)}.';
    return null;
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checkLink());
  }

  Future<void> _checkLink() async {
    final c = _conf;
    if (!mounted || c == null || c.state != 'sent') {
      _poll?.cancel();
      return;
    }
    try {
      final next = await context.read<PayoutController>().repo.confirmation(c.id);
      if (!mounted || _conf?.id != c.id) return;
      if (next.state == 'sent') return;
      _poll?.cancel();
      if (next.state == 'confirmed') {
        setState(() => _conf = next);
        showToast(context, 'Confirmed. You can withdraw now.');
      } else {
        setState(() {
          _conf = null;
          _error = context.tr('That link has expired. Send a new one.');
        });
      }
    } on ApiException {
      // Keep waiting; the next tick tries again.
    }
  }

  Future<void> _sendLink(PayoutAccount? account) async {
    if (_conf?.state == 'confirmed') return showToast(context, 'Already confirmed.');
    final problem = _check(account);
    if (problem != null) return setState(() => _error = problem);
    final amount = _amountValue!;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // A new link each time: "Send the link again" replaces the one before.
      final payload = '$amount|${account!.id}|${_conf?.id ?? ''}';
      final conf = await context.read<PayoutController>().repo.requestConfirmation(
        amount: amount,
        accountId: account.id,
        idempotencyKey: _keyFor(_sendKey, payload, (k) => _sendKey = k),
      );
      if (!mounted) return;
      setState(() => _conf = conf);
      _startPolling();
      showToast(context, '${context.tr('We emailed a link to')} ${conf.emailMasked ?? context.tr('your email')}.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _message(ApiException e) {
    if (e.code == 'withdrawals_paused') {
      final details = e.extra['details'];
      final until = DateTime.tryParse('${details is Map ? details['pause_until'] : ''}');
      if (until != null) return pauseLine(context, until);
    }
    if (e.code == 'insufficient_funds' && _summary != null) {
      return '${context.tr('There is not enough money in your wallet for this.')} ${context.tr('Available to withdraw')}: ${money(_summary!.available)}.';
    }
    return context.tr(payoutErrorMessage(e));
  }

  Future<void> _withdraw(PayoutAccount? account) async {
    final problem = _check(account);
    if (problem != null) return setState(() => _error = problem);
    final amount = _amountValue!;
    final conf = _conf;
    if (conf == null || conf.state != 'confirmed' || !_matches(conf, amount, account!.id)) {
      return setState(
        () => _error = context.tr(conf?.state == 'sent' ? 'Open the link we emailed you, then tap Withdraw again.' : 'Confirm from your email first: tap Send the link.'),
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payouts = context.read<PayoutController>();
    try {
      final w = await payouts.repo.submit(confirmationId: conf.id, amount: amount, accountId: account.id, idempotencyKey: _keyFor(_submitKey, conf.id, (k) => _submitKey = k));
      if (!mounted) return;
      await tell(
        context,
        title: 'Withdrawal requested',
        body: '${money(w.amount)} ${context.tr('is on its way to')} ${w.bankName} ${w.numberMasked}. ${context.tr('A person checks it, then it arrives within one working day.')}',
      );
      if (mounted) context.back();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'email_confirmation_required' || e.code == 'confirmation_invalid') _conf = null;
        _error = _message(e);
      });
      if (e.code == 'withdrawals_paused' || e.code == 'payout_account_not_active') payouts.load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payouts = context.watch<PayoutController>();
    final me = context.watch<AuthController>().customer;
    final view = payouts.view;
    final summary = _summary;
    if (summary == null || view == null) {
      final failed = _loadError != null || payouts.error != null;
      return AppPage(
        id: R.withdraw,
        child: failed ? DErrorState(onRetry: _load) : const DLoading(height: 300),
      );
    }
    final unverified = me != null && !me.isVerified && me.status != 'suspended';
    final account = view.inUse;
    final removing = account?.state == PayoutAccountState.removing;
    final blocked = unverified || view.paused || account == null || removing;
    final conf = _conf;
    final emailSub = switch (conf?.state) {
      'confirmed' => context.t('Confirmed for this amount'),
      'sent' => '${conf!.emailMasked ?? context.t('your email')} · ${context.t('open the link, then come back here')}',
      _ => context.t('We email you a link to confirm this withdrawal'),
    };
    final all = summary.available == summary.available.floor() ? group(summary.available) : summary.available.toStringAsFixed(2);
    return AppPage(
      id: R.withdraw,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unverified) ...[
            DNote(
              icon: 'alert-triangle',
              kind: NoteKind.wait,
              text: authErrorMessage(const ApiException(status: 403, code: 'verification_required', message: '')),
            ),
            const Gap(12),
          ],
          if (view.paused) ...[
            DNote(icon: 'clock', kind: NoteKind.wait, text: '${pauseLine(context, view.pauseUntil!)} ${context.t('Your payout account changed recently.')}'),
            const Gap(12),
          ],
          const T('Available to withdraw', style: DText.tiny),
          const Gap(6),
          T(money(summary.available), style: DText.big),
          const Gap(16),
          DField(
            label: 'Amount',
            child: DInput(controller: _amount, keyboardType: TextInputType.number, onChanged: (_) => _onAmountChanged()),
          ),
          DChips(
            children: [
              for (final v in const [10000, 25000])
                if (v < summary.available) DChip(group(v), on: _amount.text == group(v), onTap: () => _setAmount(group(v))),
              if (summary.available > 0) DChip('All of it', on: _amount.text == all, onTap: () => _setAmount(all)),
            ],
          ),
          const Gap(16),
          const DLabel('Goes to'),
          DCard(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (account == null) ...[
                  const T('No payout account in use yet', style: DText.body14),
                  const Gap(4),
                  T(
                    view.accounts.any((a) => a.state == PayoutAccountState.pendingReview)
                        ? 'Your account is waiting for the name check. You can withdraw once it is verified.'
                        : 'Add an account in your own name. A person checks the name against your ID.',
                    style: DText.tiny,
                  ),
                  const Gap(11),
                  DButton.ghost('Payout accounts', small: true, onTap: () => context.nav(R.bank)),
                ] else ...[
                  Row(
                    children: [
                      const DIcon('building-bank', size: 19, color: DColors.ink2),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${account.bankName}, ${context.t('account ending')} ${account.last4}', style: DText.body14),
                            Text(account.accountName, style: DText.tiny),
                          ],
                        ),
                      ),
                      removing ? const DPill('Removing', kind: PillKind.wait) : const DPill('Yours'),
                    ],
                  ),
                  if (removing) ...[const Gap(9), const T('This account is being removed. Keep it or use another one to withdraw.', style: DText.tiny)],
                  const Gap(11),
                  DButton.ghost('Use a different account', small: true, onTap: () => context.nav(R.bank)),
                ],
              ],
            ),
          ),
          const Gap(14),
          const DNote(icon: 'shield-lock', text: 'Money only leaves to an account in your own name. Changing this account needs a manual check and a short wait.'),
          const Gap(16),
          const DLabel("Confirm it's you"),
          DMenuCard(
            horizontalPadding: 14,
            children: [
              DMenu(
                icon: 'mail',
                title: conf == null ? 'Send the link to your email' : (conf.state == 'confirmed' ? 'Confirmed from your email' : 'Send the link again'),
                sub: emailSub,
                trailing: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : switch (conf?.state) {
                        'confirmed' => const DPill('Confirmed'),
                        'sent' => const DPill('Waiting', kind: PillKind.wait),
                        _ => null,
                      },
                onTap: blocked || _sending ? null : () => _sendLink(account),
              ),
            ],
          ),
          const Gap(16),
          DError(_error ?? '', visible: _error != null, top: 0),
          if (_error != null) const Gap(7),
          DButton('Withdraw', loading: _busy, onTap: blocked ? null : () => _withdraw(account)),
          const Gap(10),
          const Center(
            child: T('A person checks every withdrawal. It arrives within one working day. No fee from Dahab.', style: DText.tiny, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// `#s-addfunds`
class AddFundsScreen extends StatefulWidget {
  const AddFundsScreen({super.key});

  @override
  State<AddFundsScreen> createState() => _AddFundsScreenState();
}

/// Live (backend spec 009): Dahab's receiving accounts and the customer's
/// reference come from the API; "I've sent the transfer" files a notice (no
/// money moves until Dahab sees it arrive). The provider fee and daily limit
/// are shown for information only.
class _AddFundsScreenState extends State<AddFundsScreen> {
  final _amount = TextEditingController(text: '20,000');
  String? _method;
  int? _accountId;
  UploadFile? _receipt;
  String? _receiptToken;
  bool _busy = false;
  String? _error;
  String? _amountError;
  int _reload = 0;

  /// One key per submission content: a retry of the same notice reuses it, so
  /// the backend replays the first answer instead of filing a second notice.
  (String, String)? _key;

  /// `dahab-identity.allowed_mimes` plus PDF; `max_upload_kb`.
  static const _allowed = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];
  static const _maxBytes = 8192 * 1024;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The methods, or the reason this customer cannot add money yet.
  Future<(TopUpMethods?, String?)> _load() async {
    try {
      return (await context.read<WalletRepository>().topUpMethods(), null);
    } on ApiException catch (e) {
      if (e.code == 'verification_required' || e.code == 'account_suspended') return (null, authErrorMessage(e));
      // No session (signed out, or it ended): ask to sign in instead of showing an error.
      if (e.code == 'unauthenticated') return (null, _signInFirst);
      rethrow;
    }
  }

  static const _signInFirst = 'Sign in to add money to your wallet.';

  String _idempotencyKey(String payload) {
    if (_key == null || _key!.$1 != payload) _key = (payload, newIdempotencyKey());
    return _key!.$2;
  }

  Future<void> _pickReceipt() async {
    if (_receipt != null) {
      final ok = await ask(context, title: 'Replace this', body: 'You can add another receipt instead.', yes: 'Replace');
      if (!ok) return;
    }
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: _allowed);
    if (picked == null || !mounted) return;
    final ext = (picked.extension ?? '').toLowerCase();
    if (!_allowed.contains(ext)) return showToast(context, 'Use a photo (JPG, PNG, WEBP) or a PDF.');
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytes) return showToast(context, 'That file is larger than 8 MB.');
    setState(() {
      _receipt = UploadFile(
        field: 'file',
        filename: picked.name,
        bytes: bytes,
        contentType: switch (ext) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'pdf' => 'application/pdf',
          _ => 'image/jpeg',
        },
      );
      _receiptToken = null;
    });
    showToast(context, 'Added.');
  }

  Future<void> _submit() async {
    final amount = _amount.text.replaceAll(',', '').trim();
    final valid = RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(amount) && parseAmount(amount) > 0;
    setState(() => _amountError = valid ? null : 'Enter an amount above 0, e.g. 20,000.');
    if (!valid || _accountId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = context.read<WalletRepository>();
    try {
      if (_receipt != null) _receiptToken ??= await repo.uploadReceipt(_receipt!);
      await repo.submitTopUp(amount: amount, accountId: _accountId!, receiptToken: _receiptToken, idempotencyKey: _idempotencyKey('$amount|$_accountId|${_receiptToken ?? ''}'));
      if (!mounted) return;
      await tell(context, title: 'Thanks', body: 'We will match your transfer and add it to your wallet. You will get a message when it lands.');
      if (mounted) context.nav(R.topups);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.fieldError('receiving_account_id') != null) {
        // The account was switched off while you were here: show the current ones.
        setState(() {
          _accountId = null;
          _method = null;
          _reload++;
          _error = 'That account is no longer available. Pick one from the list again.';
        });
      } else if (e.code == 'upload_token_invalid') {
        setState(() {
          _receiptToken = null;
          _error = 'Your receipt expired before it was sent. Tap the button again to send it.';
        });
      } else {
        setState(() => _error = e.fieldError('amount') ?? authErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.addfunds,
      child: KeyedSubtree(
        key: ValueKey(_reload),
        child: AsyncView<(TopUpMethods?, String?)>(
          load: _load,
          builder: (context, data) {
            final (methods, blocked) = data;
            if (methods == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DNote(icon: 'alert-triangle', kind: NoteKind.wait, text: blocked ?? ''),
                  const Gap(12),
                  if (blocked == _signInFirst)
                    DButton('Sign in', onTap: () => context.nav(R.login))
                  else
                    DButton.ghost('Your top-ups', small: true, onTap: () => context.nav(R.topups)),
                ],
              );
            }
            if (methods.methods.isEmpty) {
              return const DNote(icon: 'info-circle', kind: NoteKind.wait, text: 'Adding money is not available right now. Please try again later.');
            }
            final method = _method ?? methods.methods.first.$1;
            final accounts = methods.methods.firstWhere((m) => m.$1 == method, orElse: () => methods.methods.first).$2;
            final account = accounts.firstWhere((a) => a.id == _accountId, orElse: () => accounts.first);
            _accountId ??= account.id;
            final words = TopUpWords.method(method);
            final amt = parseAmount(_amount.text);
            final fee = amt * (account.providerFeePercent ?? 0) / 100;
            final details = [
              for (final (k, v) in account.details) (TopUpWords.detailLabel(k), v),
              ('Reference', methods.reference),
              if (account.dailyLimit != null) ('Daily limit', money(account.dailyLimit!)),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DField(
                  label: 'How much do you want to add?',
                  error: _amountError,
                  child: DInput(controller: _amount, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                ),
                DChips(
                  children: [
                    for (final v in const ['5,000', '20,000', '50,000']) DChip(v, on: _amount.text == v, onTap: () => setState(() => _amount.text = v)),
                  ],
                ),
                const Gap(18),
                const DLabel('Choose a method'),
                DMenuCard(
                  horizontalPadding: 14,
                  children: [
                    for (final (code, list) in methods.methods)
                      DMenu(
                        icon: TopUpWords.method(code).icon,
                        title: TopUpWords.method(code).title,
                        sub: TopUpWords.method(code).sub,
                        onTap: () => setState(() {
                          _method = code;
                          _accountId = list.first.id;
                        }),
                        trailing: code == method ? const DIcon('circle-check', size: 16, color: DColors.ok) : const DIcon('chevron-right', size: 16, color: DColors.ink3),
                      ),
                  ],
                ),
                if (accounts.length > 1) ...[
                  const Gap(10),
                  DChips(
                    children: [for (final a in accounts) DChip(a.label, on: a.id == account.id, onTap: () => setState(() => _accountId = a.id))],
                  ),
                ],
                const Gap(14),
                DSoft.bordered(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DRow('You send', money(amt)),
                      DRow(account.providerFeePercent == null ? words.feeLabel : '${words.feeLabel}, ${account.providerFeePercent}%', fee > 0 ? '− ${money(fee)}' : 'None'),
                      DRow('Reaches your wallet', money(amt - fee), rule: true, bold: true, keyIsLabel: false),
                      if (account.note != null) ...[const Gap(8), T(account.note!, style: DText.tiny)],
                    ],
                  ),
                ),
                const Gap(14),
                DCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DLabel(words.detailTitle, bottom: 10),
                      for (final (k, v) in details) DRow(k, v, padding: const EdgeInsets.symmetric(vertical: 6)),
                      const Gap(11),
                      DButton.ghost(
                        words.copyLabel,
                        small: true,
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: [for (final (k, v) in details) '${context.tr(k)}: $v'].join('\n')));
                          if (context.mounted) showToast(context, 'Copied.');
                        },
                      ),
                    ],
                  ),
                ),
                const Gap(14),
                const DNote(
                  icon: 'info-circle',
                  kind: NoteKind.wait,
                  text: 'Use the reference above so your transfer is matched automatically. Transfers without it take longer to appear.',
                ),
                const Gap(16),
                const DLabel('Proof of transfer'),
                DSlot(
                  title: 'Add a screenshot or receipt',
                  sub: _receipt == null ? 'Speeds things up if the reference is missing' : _receipt!.filename,
                  done: _receipt != null,
                  onTap: _busy ? () {} : _pickReceipt,
                ),
                const Gap(8),
                const T('Optional when you use the reference. Needed if you transferred without it.', style: DText.tiny),
                if (_error != null) ...[const Gap(12), DNote(icon: 'alert-triangle', kind: NoteKind.wait, text: _error!)],
                const Gap(16),
                DButton("I've sent the transfer", loading: _busy, onTap: _busy ? null : _submit),
                const Gap(12),
                Center(child: DLink('Your top-ups', onTap: () => context.nav(R.topups))),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Backend spec 009: the customer's own transfer notices and hand credits,
/// with a cancel for pending ones. A suspended customer may still see and
/// cancel here, but cannot add money.
class TopUpsScreen extends StatefulWidget {
  const TopUpsScreen({super.key});

  @override
  State<TopUpsScreen> createState() => _TopUpsScreenState();
}

class _TopUpsScreenState extends State<TopUpsScreen> {
  int _reload = 0;
  String? _cancelling;

  Future<void> _cancel(TopUp t) async {
    final ok = await ask(context, title: 'Cancel this top-up', body: 'Only if you did not send the money. Nothing is taken from your wallet.', yes: 'Cancel it');
    if (!ok || !mounted) return;
    setState(() => _cancelling = t.id);
    try {
      await context.read<WalletRepository>().cancelTopUp(t.id, idempotencyKey: newIdempotencyKey());
      if (mounted) showToast(context, 'Cancelled.');
    } on ApiException catch (e) {
      if (mounted) {
        showToast(context, e.code == 'illegal_topup_transition' ? 'This top-up is already being handled, so it can no longer be cancelled.' : authErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = null;
          _reload++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.topups,
      child: KeyedSubtree(
        key: ValueKey(_reload),
        child: AsyncView<List<TopUp>>(
          load: context.read<WalletRepository>().topUps,
          builder: (context, rows) {
            if (rows.isEmpty) {
              return Column(
                children: [
                  const DCard(
                    padding: EdgeInsets.all(22),
                    child: Center(child: T('No top-ups yet.', style: DText.tiny)),
                  ),
                  const Gap(14),
                  DButton('Add funds', onTap: () => context.nav(R.addfunds)),
                ],
              );
            }
            return DMenuCard(
              children: [
                for (final t in rows)
                  DMenu(
                    icon: TopUpWords.method(t.method).icon,
                    title: '${context.tr(TopUpWords.method(t.method).title)} · ${money(t.creditedAmount ?? t.claimedAmount ?? 0)}',
                    sub: [
                      '${t.number}, ${t.date}',
                      context.tr(TopUpWords.status(t.status)),
                      if (t.status == TopUpStatus.rejected) context.tr(TopUpWords.rejectReason(t.rejectReason)),
                      if (t.expectedAmount != null) '${context.tr('About')} ${context.tr(money(t.expectedAmount!))} ${context.tr('reaches your wallet')}',
                      if (t.creditedAmount != null && t.claimedAmount != null && t.creditedAmount != t.claimedAmount)
                        '${context.tr('You said')} ${context.tr(money(t.claimedAmount!))}',
                    ].join(' · '),
                    showChevron: false,
                    trailing: t.canCancel ? DButton.ghost('Cancel', small: true, loading: _cancelling == t.id, onTap: _cancelling == null ? () => _cancel(t) : null) : null,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `#s-invoices`
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _filter = 'all';

  static const _summaryText =
      'DAHAB — INVOICE SUMMARY 2026\n\n'
      'DH-2026-004417  28 Aug  Sold gold ring          56,952.00 EGP\n'
      'DH-2026-004392  19 Aug  Bought mixed earrings   78,400.00 EGP\n'
      'DH-2026-004310  02 Aug  Sold gold bracelet      41,220.00 EGP\n\n'
      'All invoices are filed with the Egyptian Tax Authority.';

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.invoices,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DChips(
            children: [
              for (final (id, label) in const [('all', 'All'), ('sold', 'Sold'), ('bought', 'Bought')]) DChip(label, on: _filter == id, onTap: () => setState(() => _filter = id)),
            ],
          ),
          const Gap(14),
          AsyncView<List<InvoiceSummary>>(
            load: context.read<WalletRepository>().invoices,
            builder: (context, all) {
              final list = _filter == 'all' ? all : all.where((i) => i.kind == _filter).toList();
              return DMenuCard(
                children: [for (final i in list) DMenu(icon: 'receipt-2', title: i.number, sub: i.sub, onTap: () => context.nav(R.invoice))],
              );
            },
          ),
          const Gap(14),
          DButton.ghost('Download all as one file', onTap: () => _download(context, 'dahab-invoices-2026.txt', _summaryText)),
          const Gap(10),
          const Center(
            child: T('Every invoice is also filed with the Tax Authority under your name.', style: DText.tiny, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

/// `#s-invoice` — tax invoice for one sale.
class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({super.key});

  static const _text =
      'DAHAB — TAX INVOICE\nInvoice DH-2026-004417\nDate 28 August 2026\n\n'
      'Seller  Mona Hassan Ibrahim (Seller 4417)\nItem    Gold ring, 21K, 8.00 g\n\n'
      'SETTLEMENT\n  Gold value at 6,951 per gram      55,608.00 EGP\n  Making charge back               1,680.00 EGP\n'
      '  Gross                             57,288.00 EGP\n\n'
      'DAHAB CHARGES\n  Commission, 20% of making charge        336.00 EGP\n'
      '    Net of VAT                        294.74 EGP\n    VAT at 14%                         41.26 EGP\n\n'
      'PAID TO WALLET                      56,952.00 EGP\n\n'
      'Priced at the Dahab sell rate of 6,951 EGP per gram for 21K,\ntaken from the live exchange rate when the request was locked.\n\n'
      'TRANSACTION TRAIL\n  24 Aug 11:04  Listed at 57,288 EGP\n  26 Aug 19:22  Request accepted, price locked\n'
      '  28 Aug 13:40  IGI verified 21K at 8.00 g, cert IGI-EG-88214\n  28 Aug 14:05  Settled to wallet\n\n'
      'Filed with the Egyptian Tax Authority e-invoicing system.\nTax registration 000-000-000';

  @override
  Widget build(BuildContext context) {
    const indent = EdgeInsetsDirectional.only(start: 12, top: 4, bottom: 4);
    return AppPage(
      id: R.invoice,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('DH-2026-004417, 28 August 2026', style: DText.tiny),
          const Gap(14),
          const Row(
            children: [
              DPill('You sold'),
              SizedBox(width: 9),
              Expanded(child: T('Gold ring, 21K, 8.00 g', style: DText.body13)),
            ],
          ),
          const Gap(14),
          const DLabel('Settlement'),
          const DSoft.bordered(
            child: Column(
              children: [
                DRow('Gold value at 6,951 per gram', '55,608 EGP'),
                DRow('Making charge back', '+1,680 EGP', valueColor: DColors.ok),
                DRow('Gross', '57,288 EGP', rule: true),
              ],
            ),
          ),
          const Gap(14),
          const DLabel('Dahab charges'),
          DSoft.bordered(
            child: Column(
              children: [
                const DRow('Commission, 20% of the making charge', '336 EGP'),
                DRow(
                  'Net of VAT',
                  '294.74 EGP',
                  padding: indent,
                  keyWidget: const T('Net of VAT', style: DText.tiny),
                  valueWidget: const T('294.74 EGP', style: DText.tiny),
                ),
                DRow(
                  'VAT at 14%',
                  '41.26 EGP',
                  padding: indent,
                  keyWidget: const T('VAT at 14%', style: DText.tiny),
                  valueWidget: const T('41.26 EGP', style: DText.tiny),
                ),
                const DRow('Total charges', '336 EGP', rule: true),
              ],
            ),
          ),
          const Gap(14),
          const DNote(
            icon: 'wallet',
            kind: NoteKind.ok,
            textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            text: 'Paid to your wallet, 56,952 EGP',
          ),
          const Gap(15),
          const T('Priced at the Dahab sell rate of 6,951 EGP per gram for 21K, taken from the live exchange rate when the request was locked.', style: DText.tiny),
          const Gap(15),
          const DLabel('Transaction trail'),
          const DTrack(
            steps: [
              DStep('Listed at 57,288 EGP', '24 Aug, 11:04', state: TrackState.done),
              DStep('Request accepted, price locked', '26 Aug, 19:22', state: TrackState.done),
              DStep('IGI verified 21K at 8.00 g', '28 Aug, 13:40, certificate IGI-EG-88214', state: TrackState.done),
              DStep('Settled to wallet', '28 Aug, 14:05', state: TrackState.done),
            ],
          ),
          const Gap(15),
          const DNote(icon: 'file-check', text: 'Filed with the Egyptian Tax Authority e-invoicing system. Tax registration 000-000-000.'),
          const Gap(15),
          DButton.ghost('Download this invoice', onTap: () => _download(context, 'DH-2026-004417.txt', _text)),
        ],
      ),
    );
  }
}
