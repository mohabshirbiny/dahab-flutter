import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../services/live_rates.dart';
import '../../services/pricing.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';

/// Small "what this is about" card at the top of several flows.
class OrderContextCard extends StatelessWidget {
  const OrderContextCard(this.title, this.sub, {super.key, this.padding = 14});

  final String title;
  final String sub;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return DCard(
      padding: EdgeInsets.all(padding),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            T(title, style: DText.title),
            const Gap(3),
            T(sub, style: DText.tiny),
          ],
        ),
      ),
    );
  }
}

/// `#s-branch` — choose the IGI branch after accepting a request.
class BranchScreen extends StatefulWidget {
  const BranchScreen({super.key});

  @override
  State<BranchScreen> createState() => _BranchScreenState();
}

class _BranchScreenState extends State<BranchScreen> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.branch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Choose where to take the piece. Your deadline is counted in working hours at the branch you pick.', style: DText.muted),
          const Gap(16),
          AsyncView<List<Branch>>(
            load: context.read<ContentRepository>().branches,
            loadingHeight: 200,
            builder: (context, branches) => Column(
              children: [
                for (var i = 0; i < branches.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == branches.length - 1 ? 14 : 10),
                    child: _BranchCard(b: branches[i], picked: _picked == i, onTap: () => setState(() => _picked = i)),
                  ),
              ],
            ),
          ),
          const DNote(icon: 'clock', text: 'You accepted at 16:00 on Thursday. With 12 working hours and the weekend closed, your deadline at Nasr City is Sunday at 14:00.'),
          const Gap(14),
          DButton(
            'Confirm the branch',
            onTap: () async {
              await tell(context, title: 'Branch chosen', body: 'Your deadline and directions are in the order. We will remind you before it runs out.');
            },
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({required this.b, required this.picked, required this.onTap});

  final Branch b;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DCard(
      onTap: onTap,
      borderColor: picked ? DColors.gold : null,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(b.name, style: DText.title),
                    const Gap(3),
                    T(b.address, style: DText.tiny),
                  ],
                ),
              ),
              DPill(b.status, kind: b.open ? PillKind.ok : PillKind.wait),
            ],
          ),
          const Gap(11),
          DSoft.paper(child: Column(children: [DRow('Open', b.hours), DRow('Closed', b.closed), DRow('Usually done in', b.duration)])),
        ],
      ),
    );
  }
}

/// `#s-editprice` — change the making charge on a live listing.
class EditPriceScreen extends StatefulWidget {
  const EditPriceScreen({super.key});

  @override
  State<EditPriceScreen> createState() => _EditPriceScreenState();
}

class _EditPriceScreenState extends State<EditPriceScreen> {
  double _making = 180;

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<LiveRates>().rate(18);
    final q = Pricing.gold(rate: rate, weight: 5.2, makingPerGram: _making);
    return AppPage(
      id: R.editprice,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(
            icon: 'info-circle',
            text: "You can change your making charge whenever no one has an open request on the piece. The listing keeps its history, so you don't lose the views it has built up.",
          ),
          const Gap(14),
          const DLabel('Gold bracelet, 18K, 5.20 g', bottom: 12),
          DSlider(label: 'Making charge', value: _making, min: 0, max: 1000, step: 10, display: '${_making.round()} /g', onChanged: (v) => setState(() => _making = v)),
          DSoft.bordered(
            child: Column(
              children: [
                DRow('Gold value', money(q.goldValue)),
                DRow('Making charge back', '+ ${money(q.making)}', valueColor: DColors.ok),
                DRow('Dahab commission', '− ${money(q.commission)}'),
                DRow(
                  'You would receive',
                  '',
                  rule: true,
                  keyWidget: const T('You would receive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  valueWidget: T(money(q.net), style: DText.price),
                ),
              ],
            ),
          ),
          const Gap(16),
          DButton('Save', onTap: () => showToast(context, 'Making charge updated.')),
        ],
      ),
    );
  }
}
