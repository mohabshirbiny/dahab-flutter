import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payout.dart';
import '../../models/reference.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../services/payout_controller.dart';
import '../../widgets/widgets.dart';

/// One sentence per refusal of a payout or withdrawal change (backend spec 013).
String payoutErrorMessage(ApiException e) => switch (e.code) {
  'withdrawals_paused' => 'Withdrawals are paused after a change of payout account.',
  'payout_account_not_active' => 'This payout account cannot receive money now.',
  'illegal_payout_account_transition' => 'This account has already changed. The list has been refreshed.',
  'illegal_withdrawal_transition' => 'This withdrawal has already moved on. The list has been refreshed.',
  'declaration_required' => 'Confirm the account is yours and the name matches your ID.',
  'email_confirmation_required' => 'Confirm this withdrawal from the link we emailed you first.',
  'confirmation_invalid' => 'This link has expired or was already used. Ask for a new one in the app.',
  'insufficient_funds' => 'There is not enough money in your wallet for this.',
  'idempotency_in_progress' => 'The first attempt is still being processed. Wait a moment and try again.',
  _ => authErrorMessage(e),
};

/// "3 Oct 2026" / "3 أكتوبر 2026"
String _day(DateTime? at) => at == null ? '' : dayMonthYear(at);

/// "Withdrawals are paused until 3 Oct, 14:00."
String pauseLine(BuildContext context, DateTime until) => '${context.tr('Withdrawals are paused until')} ${whenOf(until)}.';

/// `#s-bank` — payout accounts, the pause and the recent changes (live, backend spec 013).
class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  String? _busy;

  @override
  void initState() {
    super.initState();
    context.read<PayoutController>().load();
  }

  String _label(PayoutAccount a) => '${a.bankName}, ${context.tr('account ending')} ${a.last4}';

  Future<void> _run(PayoutAccount a, Future<void> Function() action) async {
    setState(() => _busy = a.id);
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, payoutErrorMessage(e));
      if (e.code.startsWith('illegal_')) await context.read<PayoutController>().load();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _use(PayoutController c, PayoutAccount a) async {
    final first = c.view?.inUse == null;
    if (!first) {
      final ok = await ask(
        context,
        title: 'Use this account',
        body:
            '${context.tr('Withdrawals that have not left yet are cancelled and the money comes back to your wallet.')}\n\n${context.tr('New withdrawals pause for a while after the change. We tell you on your phone and email.')}',
        yes: 'Use this one',
      );
      if (!ok || !mounted) return;
    }
    await _run(a, () async {
      final cancelled = await c.use(a);
      if (!mounted) return;
      final until = c.view?.pauseUntil;
      showToast(context, until == null ? 'Done.' : pauseLine(context, until));
      if (cancelled.isNotEmpty) {
        await tell(context, title: 'Withdrawals cancelled', body: '${context.tr('Cancelled and returned to your wallet:')} ${cancelled.join(', ')}');
      }
    });
  }

  Future<void> _remove(PayoutController c, PayoutAccount a) async {
    final pending = a.state == PayoutAccountState.pendingReview;
    final only = a.inUse && c.view!.accounts.where((x) => x.state != PayoutAccountState.refused).length == 1;
    final ok = await ask(
      context,
      title: pending ? 'Cancel this request' : 'Remove this account',
      body: pending
          ? context.tr('We stop checking this account.')
          : only
          ? context.tr('This is your only payout account. You will not be able to withdraw until you add another one.')
          : '${context.tr('Remove')} ${_label(a)}? ${context.tr('If a withdrawal is on its way to it, we keep it until that withdrawal finishes.')}',
      yes: pending ? 'Cancel the request' : 'Remove',
    );
    if (!ok || !mounted) return;
    await _run(a, () async {
      await c.remove(a);
      if (!mounted) return;
      final still = c.view?.accounts.where((x) => x.id == a.id).firstOrNull;
      showToast(
        context,
        pending
            ? 'Request cancelled.'
            : still?.state == PayoutAccountState.removing
            ? 'Scheduled. We told you on your phone and email.'
            : 'Removed. We told you on your phone and email.',
      );
    });
  }

  Future<void> _keep(PayoutController c, PayoutAccount a) => _run(a, () async {
    await c.keep(a);
    if (mounted) showToast(context, 'Kept.');
  });

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PayoutController>();
    final me = context.watch<AuthController>().customer;
    final view = c.view;
    if (view == null) {
      return AppPage(
        id: R.bank,
        child: c.error != null ? DErrorState(onRetry: c.load) : const DLoading(),
      );
    }
    final unverified = me != null && !me.isVerified && me.status != 'suspended';
    return AppPage(
      id: R.bank,
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
          const DLabel('Where your money goes'),
          if (view.accounts.isEmpty)
            const DCard(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    T('No payout account yet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Gap(4),
                    T('Add one before your first withdrawal.', style: DText.tiny),
                  ],
                ),
              ),
            )
          else
            for (final a in view.accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BankCard(a: a, busy: _busy == a.id, onUse: () => _use(c, a), onRemove: () => _remove(c, a), onKeep: () => _keep(c, a)),
              ),
          const Gap(2),
          DButton.ghost(view.accounts.isEmpty ? 'Add an account' : 'Add another account', small: true, onTap: () => context.nav(R.bankadd)),
          const Gap(16),
          const DNote(icon: 'shield-lock', text: 'The account name must match the name on your ID. We check this before the first payout, and again whenever it changes.'),
          if (view.changes.isNotEmpty) ...[
            const Gap(16),
            const DLabel('Recent changes'),
            DMenuCard(
              children: [
                for (final e in view.changes)
                  DMenu(
                    title: PayoutWords.change(e.kind),
                    sub: '${e.bankName} ${e.numberMasked} · ${_day(e.at)} · ${context.t(e.byYou ? 'by you' : 'by Dahab')}',
                    showChevron: false,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.a, required this.busy, required this.onUse, required this.onRemove, required this.onKeep});

  final PayoutAccount a;
  final bool busy;
  final VoidCallback onUse;
  final VoidCallback onRemove;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final tag = switch (a.state) {
      PayoutAccountState.removing => const DPill('Removing', kind: PillKind.wait),
      PayoutAccountState.pendingReview => const DPill('Under review', kind: PillKind.wait),
      PayoutAccountState.refused => const DPill('Refused', kind: PillKind.bad),
      _ => a.inUse ? const DPill('In use') : null,
    };
    return DCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DIcon('building-bank', size: 19, color: DColors.ink2),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a.bankName}, ${context.t('account ending')} ${a.last4}', style: DText.body14),
                    Text('${a.accountName} · ${context.t('added')} ${_day(a.addedAt)}', style: DText.tiny),
                  ],
                ),
              ),
              ?tag,
            ],
          ),
          if (a.state == PayoutAccountState.removing) ...[
            const Gap(10),
            const T('This account is removed once the withdrawal in progress finishes. Money still goes here until then.', style: DText.tiny),
            if (a.canKeep) ...[const Gap(9), DButton.ghost('Keep it after all', small: true, loading: busy, onTap: onKeep)],
          ] else if (a.state == PayoutAccountState.pendingReview) ...[
            const Gap(10),
            const T('Waiting for us to check the name against your ID. You can still withdraw to the account in use meanwhile.', style: DText.tiny),
            if (a.canRemove) ...[const Gap(9), DButton.ghost('Cancel this request', small: true, loading: busy, onTap: onRemove)],
          ] else if (a.state == PayoutAccountState.refused) ...[
            const Gap(10),
            T(PayoutWords.refusal(a.refusalReason), style: DText.tiny),
            const Gap(4),
            const T('Add the account again with the right details.', style: DText.tiny),
          ] else if (a.canUse || a.canRemove) ...[
            const Gap(11),
            Row(
              children: [
                if (a.canUse) ...[DButton.ghost('Use this one', small: true, loading: busy, onTap: onUse), const SizedBox(width: 9)],
                if (a.canRemove) DButton.ghost('Remove', small: true, onTap: busy ? null : onRemove),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `#s-bankadd` — sends a new account for the name check (live, backend spec 013).
class BankAddScreen extends StatefulWidget {
  const BankAddScreen({super.key});

  @override
  State<BankAddScreen> createState() => _BankAddScreenState();
}

class _BankAddScreenState extends State<BankAddScreen> {
  final _bank = TextEditingController();
  final _name = TextEditingController();
  final _number = TextEditingController();
  late final Future<LegalDoc> _declaration = context.read<PayoutController>().repo.declaration();
  bool _confirm = false;
  bool _error = false;
  bool _busy = false;
  ApiException? _failure;

  @override
  void dispose() {
    for (final c in [_bank, _name, _number]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if ([_bank, _name, _number].any((c) => c.text.trim().isEmpty) || !_confirm) return setState(() => _error = true);
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final declaration = await _declaration;
      if (!mounted) return;
      await context.read<PayoutController>().add(bankName: _bank.text.trim(), accountName: _name.text.trim(), number: _number.text.trim(), declarationId: declaration.id);
      if (!mounted) return;
      await tell(context, title: 'Sent for review', body: 'We check the account name against your ID. You will hear back on your phone and email, usually within a few hours.');
      if (mounted) context.back();
    } on ApiException catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (_) {
      if (mounted) setState(() => _failure = const ApiException(status: 0, code: 'network_error', message: ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = _failure;
    final fields = f?.code == 'validation_failed' && f!.fieldErrors.isNotEmpty;
    final arabic = context.watch<LangController>().isArabic;
    return AppPage(
      id: R.bankadd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(
            icon: 'alert-triangle',
            kind: NoteKind.wait,
            text:
                "Once checked, making this the account in use cancels any withdrawal that hasn't left yet and pauses new withdrawals for a while. We will tell you on your phone and email.",
          ),
          const Gap(16),
          DField(
            label: 'Bank',
            error: f?.fieldError('bank_name'),
            child: DInput(controller: _bank, hint: 'CIB, Banque Misr, NBE...'),
          ),
          DField(
            label: 'Account holder name',
            error: f?.fieldError('account_name'),
            child: DInput(controller: _name, hint: 'Exactly as written on your ID'),
          ),
          DField(
            label: 'Account number or IBAN',
            error: f?.fieldError('account_number_or_iban'),
            child: DInput(controller: _number, hint: 'EG00 0000 0000 0000 0000 0000 0000'),
          ),
          const Gap(6),
          const DNote(
            icon: 'alert-triangle',
            kind: NoteKind.wait,
            text: 'Check the account number carefully. If it is wrong the transfer bounces back from the bank, which can take several days.',
          ),
          const Gap(14),
          FutureBuilder<LegalDoc>(
            future: _declaration,
            builder: (context, snap) {
              final doc = snap.data;
              final text = doc == null
                  ? 'I confirm this account is mine, the details are correct, and the name matches my ID.'
                  : (arabic && doc.bodyAr.isNotEmpty ? doc.bodyAr : doc.bodyEn);
              return DCheck(
                value: _confirm,
                onChanged: (v) => setState(() {
                  _confirm = v;
                  _error = false;
                }),
                text: text,
              );
            },
          ),
          DError('Fill in every field and confirm the account is yours.', visible: _error),
          DError(f == null || fields ? '' : payoutErrorMessage(f), visible: f != null && !fields),
          const Gap(10),
          DButton('Send for review', loading: _busy, onTap: _send),
          const Gap(10),
          const Center(
            child: T('A person checks the name against your ID. Usually within a few hours.', style: DText.tiny, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
