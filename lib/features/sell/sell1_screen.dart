import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reference.dart';
import '../../services/live_rates.dart';
import '../../services/pricing.dart';
import '../../services/repositories.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';

/// `#s-sell1` — what are you selling, and what you would receive.
class Sell1Screen extends StatelessWidget {
  const Sell1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    // What Dahab accepts now (karats, piece types) comes from the backend.
    return AppPage(
      id: R.sell1,
      child: AsyncView<SellReference>(
        load: context.read<ReferenceRepository>().sellReference,
        loadingHeight: 300,
        builder: (context, ref) => _Sell1Body(ref: ref),
      ),
    );
  }
}

class _Sell1Body extends StatelessWidget {
  const _Sell1Body({required this.ref});

  final SellReference ref;

  @override
  Widget build(BuildContext context) {
    context.read<SellDraft>().syncWith(ref);
    final d = context.watch<SellDraft>();
    final rates = context.watch<LiveRates>();
    final q = d.quote(rates);
    final pricesPaused = rates.quotePaused || rates.paused;
    final isGold = d.type == SellType.gold;
    final isDiamond = d.type == SellType.diamond;
    final isMixed = d.type == SellType.mixed;
    final arabic = context.isArabic;
    final kinds = [for (final t in ref.pieceTypes.where((t) => t.category == d.category)) (t.id, arabic && t.nameAr.isNotEmpty ? t.nameAr : t.nameEn)];
    final kindGrid = <Widget>[
      const DLabel('Type of piece', bottom: 6),
      if (kinds.isEmpty)
        const DNote(icon: 'info-circle', kind: NoteKind.wait, text: 'Dahab is not accepting this kind of piece right now.')
      else
        DKindGrid<int>(options: kinds, value: d.pieceTypeId ?? kinds.first.$1, onChanged: (v) => d.update((d) => d.pieceTypeId = v)),
      const Gap(10),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const T('Step 1 of 3', style: DText.tiny),
        const Gap(14),
        const DLabel('What are you selling'),
        if (d.editing == null)
          DSeg<SellType>(
            options: const [(SellType.gold, 'Gold'), (SellType.diamond, 'Diamond'), (SellType.mixed, 'Gold and diamond')],
            value: d.type,
            onChanged: (v) => d.update((d) => d.type = v, resetsStone: true),
          )
        else ...[
          T(switch (d.type) {
            SellType.gold => 'Gold',
            SellType.diamond => 'Diamond',
            SellType.mixed => 'Gold and diamond',
          }, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Gap(4),
          const T('This cannot change once a listing exists. To sell something else, start a new listing.', style: DText.tiny),
        ],
        const Gap(18),

        // ---- gold block (gold, mixed) ----
        if (isGold || isMixed) ...[
          const DLabel('Gold'),
          DSeg<int>(options: [for (final k in ref.karats) (k, '${k}K')], value: d.karat, onChanged: (v) => d.update((d) => d.karat = v)),
          const Gap(14),
          ...kindGrid,
          DSlider(label: 'Weight', value: d.weight, min: 0.5, max: 50, step: 0.1, display: '${d.weight.toStringAsFixed(1)} g', onChanged: (v) => d.update((d) => d.weight = v)),
          Transform.translate(
            offset: const Offset(0, -6),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DLink('Not sure of the weight?', onTap: () => context.nav(R.weight)),
            ),
          ),
          const Gap(6),
          if (isGold) ...[
            DSlider(label: 'Making charge', value: d.making, min: 0, max: 1000, step: 10, display: '${d.making.round()} /g', onChanged: (v) => d.update((d) => d.making = v)),
            const DNote(
              icon: 'bulb',
              text:
                  'A useful guide: about half of what the making charge would be on a new piece. Rare or signed pieces can ask for more. You get what you set here, less commission.',
            ),
            const Gap(16),
          ],
        ],

        // ---- stone block (diamond) ----
        if (isDiamond) ...[
          const DLabel('Diamond'),
          ...kindGrid,
          const Gap(4),
          DSlider(
            label: 'Carat',
            value: d.carat,
            min: 0.1,
            max: 3,
            step: 0.1,
            display: d.carat.toStringAsFixed(1),
            onChanged: (v) => d.update((d) => d.carat = v, resetsStone: true),
          ),
          const DLabel('Clarity', bottom: 6),
          DSeg<double>(
            options: const [(1.35, 'VVS'), (1.0, 'VS'), (0.78, 'SI'), (0.55, 'I')],
            value: d.clarity,
            onChanged: (v) => d.update((d) => d.clarity = v, resetsStone: true),
          ),
          const Gap(13),
          const DLabel('Cut', bottom: 6),
          DSeg<double>(options: const [(1.12, 'Excellent'), (1.0, 'Very good'), (0.85, 'Good')], value: d.cut, onChanged: (v) => d.update((d) => d.cut = v, resetsStone: true)),
          const Gap(14),
          DSoft.bordered(
            margin: const EdgeInsets.only(bottom: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('Suggested price for this stone', style: DText.tiny),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: T(money(d.suggestedStone), style: DText.price),
                ),
                const T('A guide from the Rapaport matrix, updated 28 Aug. IGI confirms the grade and value.', style: DText.tiny),
              ],
            ),
          ),
          DSlider(
            label: 'You ask',
            value: d.stoneAsk,
            min: 0,
            max: 150000,
            step: 500,
            display: group(d.stoneAsk),
            onChanged: (v) => d.update((d) => d.stoneAsk = v, touchesStone: true),
          ),
        ],

        // ---- certificate (diamond, mixed) ----
        if (isDiamond || isMixed) ...[
          const DLabel('Stone certificate'),
          DSeg<String>(
            options: const [('igi', 'IGI certificate'), ('other', 'Another lab'), ('none', 'No certificate')],
            value: d.cert,
            fontSize: 12,
            onChanged: (v) => d.update((d) => d.cert = v),
          ),
          const Gap(12),
          if (d.cert != 'none') ...[
            DSlot(
              title: 'Upload the certificate',
              sub: d.has('cert') ? 'Added' : 'A clear photo or a PDF',
              subColor: d.has('cert') ? DColors.ok : null,
              icon: 'certificate',
              iconSize: 21,
              boxHeight: 52,
              done: d.has('cert'),
              onTap: () => pickIntoSlot(context, 'cert'),
            ),
            const Gap(10),
          ],
          DNote(
            icon: 'info-circle',
            text: switch (d.cert) {
              'igi' => 'An IGI certificate costs you nothing. We check it against the stone at handover.',
              'other' =>
                'Upload it and buyers can see it while browsing. IGI still issues its own certificate, at a lower cost because they have something to start from, taken from your settlement.',
              _ => 'IGI issues one for you. The full cost is taken from your settlement when the piece sells.',
            },
          ),
          const Gap(16),
        ],

        // ---- total price (mixed) ----
        if (isMixed) ...[
          const DLabel('Your price for the whole piece'),
          DSlider(label: 'You ask', value: d.totalAsk, min: 0, max: 300000, step: 1000, display: group(d.totalAsk), onChanged: (v) => d.update((d) => d.totalAsk = v)),
          if (q != null)
            DNote(
              icon: 'info-circle',
              spans: [
                TextSpan(text: '${context.t('The gold in your piece is worth')} '),
                TextSpan(
                  text: context.t(money(q.goldValue)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' ${context.t('today. Ask above that to recover the making charge and the stone.')}'),
              ],
            ),
          const Gap(16),
        ],

        // ---- summary ---- the backend's quote (spec 015)
        if (q == null)
          DNote(
            icon: 'clock',
            kind: pricesPaused ? NoteKind.wait : NoteKind.plain,
            text: pricesPaused ? 'Prices are paused right now. Your estimate shows again as soon as they are back.' : 'Working out what you would receive…',
          )
        else
          DSoft.bordered(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                if (isGold || isMixed) DRow('Gold value', money(q.goldValue)),
                if (isGold) DRow('Making charge back', '+ ${money(q.making)}', valueColor: DColors.ok),
                if (isDiamond) DRow('Stone value', '+ ${money(q.stone)}', valueColor: DColors.ok),
                if (isMixed) DRow('Your asking price', money(q.ask)),
                DRow(
                  '',
                  '− ${money(q.commission)}',
                  keyWidget: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${context.t('Dahab commission')} '),
                        TextSpan(text: context.t(q.commissionNote), style: DText.tiny),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13, color: DColors.ink2),
                  ),
                ),
                if (d.promo != null) DRow('Promo saving', '+ ${money(q.promoSaving)}', keyColor: DColors.ok, valueColor: DColors.ok),
                DRow(
                  'You receive',
                  '',
                  rule: true,
                  keyIsLabel: false,
                  keyWidget: const T('You receive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  valueWidget: T(money(q.net), style: DText.price),
                ),
              ],
            ),
          ),
        // `#cmp-note` — how this compares with selling to a jeweller.
        if (isGold && q != null)
          DNote(
            icon: 'arrow-up-right',
            kind: NoteKind.ok,
            child: Column(
              children: [
                DRow('A jeweller pays gold only', money(q.jewellerPays), keyColor: DColors.ok, valueColor: DColors.ok, padding: const EdgeInsets.symmetric(vertical: 2)),
                DRow(
                  'You get extra',
                  money(q.net - q.jewellerPays),
                  keyColor: DColors.okDark,
                  valueColor: DColors.okDark,
                  valueStyle: const TextStyle(fontWeight: FontWeight.w600),
                  keyWidget: const T(
                    'You get extra',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DColors.okDark),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                ),
              ],
            ),
          )
        else
          DNote(
            icon: 'arrow-up-right',
            kind: NoteKind.ok,
            textStyle: const TextStyle(fontSize: 12, height: 1.65),
            spans: [
              TextSpan(
                text: context.t(isDiamond ? 'A jeweller discounts the stone heavily.' : 'A jeweller pays scrap gold and little for the stone.'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: ' ${context.t(isDiamond ? 'Here it is graded by IGI and priced on what it really is.' : 'Here you get the craft and the stone as well as the metal.')}',
              ),
            ],
          ),
        const Gap(16),
        MockMark(child: _PromoCard()),
        const Gap(16),
        DButton('Continue to photos', onTap: () => context.nav(R.sell2)),
      ],
    );
  }
}

class _PromoCard extends StatefulWidget {
  @override
  State<_PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<_PromoCard> {
  final _c = TextEditingController();
  String _msg = 'If you have a promo code, enter it here.';
  Color? _color;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _apply() {
    final draft = context.read<SellDraft>();
    final code = _c.text.trim();
    if (code.isEmpty) {
      draft.update((d) => d.promo = null);
      return setState(() {
        _msg = 'Try WELCOME or EID25.';
        _color = null;
      });
    }
    final p = context.read<ContentRepository>().promo(code);
    draft.update((d) => d.promo = p);
    setState(() {
      if (p == null) {
        _msg = 'That code is not valid.';
        _color = DColors.bad;
      } else {
        _msg = '${context.tr(p.label)}. ${context.tr('The 200 EGP minimum still applies.')}';
        _color = DColors.ok;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DLabel('Promo code', bottom: 8),
          Row(
            children: [
              Expanded(
                child: DInput(controller: _c, hint: 'WELCOME', uppercase: true),
              ),
              const SizedBox(width: 8),
              DButton.ghost('Apply', small: true, onTap: _apply),
            ],
          ),
          const Gap(8),
          T(_msg, style: DText.tiny.copyWith(color: _color)),
        ],
      ),
    );
  }
}
