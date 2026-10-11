import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

/// Invite a friend. A prototype screen kept on mock data: no document defines the referral rules
/// (backend spec 019 OD-2), so it is flagged MOCK and its words are not editable from App text.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.invite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const DIcon('users', size: 30, color: DColors.gold),
                const Gap(10),
                const T('Invite a friend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const Gap(6),
                const T(
                  'She pays a lower commission on her first sale. You pay a lower one on your next.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: DColors.ink2, height: 1.65),
                ),
                const Gap(14),
                const DSoft.paper(
                  child: Column(
                    children: [
                      T('Your code', style: DText.tiny),
                      Gap(3),
                      Text('MONA4417', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2)),
                    ],
                  ),
                ),
                const Gap(12),
                DActsRow(
                  children: [
                    DButton('Share', small: true, onTap: () => showToast(context, 'Ready to share.')),
                    DButton.ghost('Copy', small: true, onTap: () => showToast(context, 'Copied.')),
                  ],
                ),
              ],
            ),
          ),
          const Gap(16),
          const DLabel('Where it stands'),
          const DSoft.bordered(
            child: Column(
              children: [
                DRow('Invites sent', '3'),
                DRow('Joined', '1'),
                DRow('Sold something', '1'),
                DRow(
                  'Earned so far',
                  '200 EGP',
                  rule: true,
                  valueColor: DColors.ok,
                  valueStyle: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Gap(14),
          const T('The reward lands as commission credit after your friend completes her first sale, not when she signs up.', style: DText.tiny),
        ],
      ),
    );
  }
}

