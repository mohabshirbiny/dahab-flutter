import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/referral.dart';
import '../../core/text/texts_controller.dart';
import '../../core/utils/idempotency.dart';
import '../../models/referral.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';

/// *Invite a friend* (backend spec 023 Story 4): the customer's code, what they would each save and
/// where it stands. The reward is a commission credit, never wallet money, and lands only after the
/// friend's first sale. Open only while the programme is on; every figure is the backend's.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late Future<ReferralSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = context.read<ReferralRepository>().summary();
  }

  /// Counts the tap; a refusal or a slow answer never blocks sharing.
  Future<void> _count() async {
    try {
      await context.read<ReferralRepository>().share(idempotencyKey: newIdempotencyKey());
      if (mounted) setState(() => _summary = context.read<ReferralRepository>().summary());
    } catch (_) {
      // The counter is a courtesy.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.invite,
      child: AsyncView<ReferralSummary>(
        key: ValueKey(_summary),
        load: () => _summary,
        loadingHeight: 260,
        builder: (context, s) => _body(context, s),
      ),
    );
  }

  Widget _body(BuildContext context, ReferralSummary s) {
    if (!s.enabled || s.code == null) {
      return DNote(icon: 'info-circle', kind: NoteKind.wait, text: context.k(ReferralKeys.notAvailable));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const DIcon('users', size: 30, color: DColors.gold),
              const Gap(10),
              T(context.k(ReferralKeys.title), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const Gap(6),
              T(
                context.k(ReferralKeys.intro, {
                  'referral_friend_pct': _trim(s.friendPercentOff),
                  'referral_reward_egp': _trim(s.inviterRewardEgp),
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: DColors.ink2, height: 1.65),
              ),
              const Gap(14),
              DSoft.paper(
                child: Column(
                  children: [
                    T(context.k(ReferralKeys.yourCode), style: DText.tiny),
                    const Gap(3),
                    Text(s.code!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2)),
                  ],
                ),
              ),
              const Gap(12),
              DActsRow(
                children: [
                  DButton(
                    context.k(ReferralKeys.share),
                    small: true,
                    onTap: () async {
                      final text = context.kr(ReferralKeys.shareMessage, {'code': s.code});
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      showToast(context, context.kr(ReferralKeys.shareReady));
                      _count();
                    },
                  ),
                  DButton.ghost(
                    context.k(ReferralKeys.copy),
                    small: true,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: s.code!));
                      if (!context.mounted) return;
                      showToast(context, context.kr(ReferralKeys.copied));
                      _count();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const Gap(16),
        DLabel(context.k(ReferralKeys.stands)),
        DSoft.bordered(
          child: Column(
            children: [
              DRow(context.k(ReferralKeys.invitesSent), '${s.invitesSent}'),
              DRow(context.k(ReferralKeys.joined), '${s.joined}'),
              DRow(context.k(ReferralKeys.sold), '${s.sold}'),
              DRow(context.k(ReferralKeys.earned), moneyOf(s.earnedEgp), rule: true, valueColor: DColors.ok, valueStyle: const TextStyle(fontWeight: FontWeight.w500)),
              if (s.available > 0) DRow(context.k(ReferralKeys.available), moneyOf(s.availableEgp)),
              if (s.available > 0 && s.availableUntil != null) DRow(context.k(ReferralKeys.expires, {'date': dayMonthYear(s.availableUntil!)}), ''),
            ],
          ),
        ),
        const Gap(14),
        T(context.k(ReferralKeys.rewardNote, {'referral_expiry_days': '${s.creditExpiryDays}'}), style: DText.tiny),
      ],
    );
  }

  static String _trim(String v) {
    final n = double.tryParse(v);
    if (n == null) return v;
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }
}
