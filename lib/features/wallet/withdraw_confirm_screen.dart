import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payout.dart';
import '../../services/api/api_client.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';

/// `#/withdraw-confirm?token=` — the page the withdrawal email links to
/// (backend spec 013, Part 1 §2.4). No sign-in: the token is the secret. It
/// shows what the link confirms and confirms it; the customer then goes back
/// to the Withdraw screen, which sees the confirmation and lets them submit.
class WithdrawConfirmScreen extends StatefulWidget {
  const WithdrawConfirmScreen({super.key, required this.token});

  final String token;

  @override
  State<WithdrawConfirmScreen> createState() => _WithdrawConfirmScreenState();
}

class _WithdrawConfirmScreenState extends State<WithdrawConfirmScreen> {
  LinkConfirmation? _link;
  bool _invalid = false;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    setState(() {
      _failed = false;
      _invalid = false;
    });
    if (widget.token.length < 20) return setState(() => _invalid = true);
    try {
      final link = await context.read<PayoutRepository>().readLink(widget.token);
      if (mounted) setState(() => _link = link);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => e.code == 'confirmation_invalid' || e.code == 'validation_failed' ? _invalid = true : _failed = true);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final link = await context.read<PayoutRepository>().confirmLink(widget.token);
      if (mounted) setState(() => _link = link);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'confirmation_invalid') {
        setState(() => _invalid = true);
      } else {
        showToast(context, e.isNetwork ? "Can't reach Dahab right now. Check your connection and try again." : 'Something went wrong');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    final Widget body;
    if (_invalid || (link != null && (link.state == 'expired' || link.state == 'replaced' || link.state == 'used'))) {
      body = DEmpty(
        icon: 'alert-triangle',
        title: link?.state == 'used' ? 'This withdrawal was already sent' : 'This link has expired',
        body: link?.state == 'used' ? 'Nothing more to do here.' : 'Ask for a new one on the Withdraw screen in the app.',
        action: 'Open Dahab',
        onAction: () => context.enterApp(R.home),
      );
    } else if (_failed) {
      body = DErrorState(onRetry: _read);
    } else if (link == null) {
      body = const DLoading(height: 240);
    } else {
      final confirmed = link.state == 'confirmed';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('You asked to withdraw', style: DText.tiny),
          const Gap(6),
          T(money(link.amount), style: DText.big),
          const Gap(14),
          DSoft.bordered(
            child: Column(children: [DRow('Goes to', link.accountMasked), if (link.expiresAt != null && !confirmed) DRow('Link works until', whenOf(link.expiresAt!), rule: true)]),
          ),
          const Gap(14),
          if (confirmed) ...[
            const DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'Confirmed. Go back to the Withdraw screen in the app and tap Withdraw.'),
            const Gap(14),
            DButton('Back to Withdraw', onTap: () => context.enterApp(R.withdraw)),
          ] else ...[
            const DNote(icon: 'shield-lock', text: 'Only confirm if you asked for this withdrawal yourself. If you did not, ignore this link and change your password.'),
            const Gap(14),
            DButton('Confirm this withdrawal', loading: _busy, onTap: _confirm),
          ],
        ],
      );
    }
    return AppPage(id: R.withdrawConfirm, child: body);
  }
}
