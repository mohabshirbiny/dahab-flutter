import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/live_rates.dart';
import '../../services/pricing.dart';
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
