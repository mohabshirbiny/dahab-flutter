import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/piece.dart';
import '../../services/app_session.dart';
import '../../services/live_rates.dart';
import '../../services/pricing.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/piece_card.dart';
import '../shared/suspended_notice.dart';

/// `#s-home`
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.home,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MockMark(bottom: -8, end: 12, child: RateBar()),
          // Backend spec 007: only shown while the account is suspended.
          const SuspendedNotice(margin: EdgeInsets.fromLTRB(16, 16, 16, 0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${context.t('Sell your jewellery')}\n${context.t("for what it's really worth")}', style: DText.h2),
                const Gap(7),
                const T('No shop to shop. No haggling. The making charge is yours to recover.', style: DText.muted),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MockMark(child: _Calculator()),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 16), child: _Protections()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: T('Pieces available now', style: DText.label)),
                    DLink('See all', onTap: () => context.nav(R.browse)),
                  ],
                ),
                const Gap(10),
                AsyncView<List<Piece>>(
                  load: context.read<CatalogRepository>().pieces,
                  loadingHeight: 200,
                  builder: (context, items) => Grid2(children: [for (final p in items.where((p) => !p.mine).take(2)) PieceCard(piece: p)]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.ratebar` — live gold prices strip; tapping explains where they come from.
class RateBar extends StatelessWidget {
  const RateBar({super.key});

  @override
  Widget build(BuildContext context) {
    final rates = context.watch<LiveRates>();
    return Tappable(
      onTap: () => context.nav(R.prices),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
        decoration: const BoxDecoration(
          color: DColors.white,
          border: Border(bottom: BorderSide(color: DColors.line)),
        ),
        child: Row(
          children: [
            const DIcon('chart-line', size: 13, color: DColors.gold),
            const SizedBox(width: 9),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const T('Gold now', style: TextStyle(fontSize: 11, color: DColors.ink2)),
                    for (final k in const [18, 21, 24]) ...[
                      const SizedBox(width: 9),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 400),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                          fontFamilyFallback: DefaultTextStyle.of(context).style.fontFamilyFallback,
                          fontFeatures: DefaultTextStyle.of(context).style.fontFeatures,
                          color: switch (rates.flash(k)) {
                            1 => DColors.ok,
                            -1 => DColors.bad,
                            _ => DColors.ink,
                          },
                        ),
                        child: Text(context.t('${k}K ${group(rates.rate(k))}')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            const T('live', style: TextStyle(fontSize: 11, color: DColors.ok)),
          ],
        ),
      ),
    );
  }
}

/// "What will I get for my piece?" calculator card.
class _Calculator extends StatelessWidget {
  const _Calculator();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSession>();
    final rate = context.watch<LiveRates>().rate(s.homeKarat);
    final q = Pricing.gold(rate: rate, weight: s.homeWeight, makingPerGram: s.homeMaking);
    return DCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DLabel('What will I get for my piece?'),
          DSeg<int>(
            options: const [(18, '18K'), (21, '21K'), (24, '24K')],
            value: s.homeKarat,
            onChanged: (k) => s.setHome(karat: k),
          ),
          const Gap(14),
          DSlider(
            label: 'Weight',
            value: s.homeWeight,
            min: 0.5,
            max: 50,
            step: 0.1,
            display: '${s.homeWeight.toStringAsFixed(1)} g',
            onChanged: (v) => s.setHome(weight: v),
          ),
          DSlider(
            label: 'Making charge',
            value: s.homeMaking,
            min: 0,
            max: 1000,
            step: 10,
            display: '${s.homeMaking.round()} /g',
            onChanged: (v) => s.setHome(making: v),
          ),
          DSoft.paper(
            margin: const EdgeInsets.only(bottom: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('You would receive', style: DText.tiny),
                Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 7),
                  child: T(money(q.net), style: DText.big),
                ),
                DRow('A jeweller pays gold only', money(q.jewellerPays), padding: const EdgeInsets.symmetric(vertical: 2)),
                DRow('You get extra', '+ ${money(q.extra)}', bold: true, keyColor: DColors.ok, valueColor: DColors.ok, padding: const EdgeInsets.symmetric(vertical: 2)),
              ],
            ),
          ),
          Tappable(
            onTap: () => context.nav(R.prices),
            child: Row(
              children: [
                const DIcon('chart-line', size: 14, color: DColors.gold),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${context.t('You get')} '),
                        TextSpan(
                          text: group(rate),
                          style: const TextStyle(fontWeight: FontWeight.w500, color: DColors.ink2),
                        ),
                        TextSpan(text: ' ${context.t('EGP per gram')} · '),
                        TextSpan(
                          text: context.t('where prices come from'),
                          style: const TextStyle(color: DColors.gold),
                        ),
                      ],
                    ),
                    style: DText.tiny,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                const T('This is after Dahab commission', style: DText.tiny),
                const SizedBox(width: 6),
                DLink('Learn more', onTap: () => context.nav(R.prices)),
              ],
            ),
          ),
          const Gap(10),
          DButton('Sell my piece', onTap: context.trySell),
          const Gap(9),
          Center(
            child: DLink('Selling a diamond or a gold and diamond piece?', textAlign: TextAlign.center, onTap: () => context.nav(R.sell1)),
          ),
        ],
      ),
    );
  }
}

class _Protections extends StatelessWidget {
  const _Protections();

  @override
  Widget build(BuildContext context) {
    Widget blurb(String icon, String title, String body, {List<InlineSpan>? spans}) => DSoft(
      margin: const EdgeInsets.only(bottom: 7),
      child: DIconBlurb(icon: icon, title: title, body: spans == null ? body : null, bodySpans: spans),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DLabel("How you're protected"),
        blurb(
          'chart-line',
          "We don't set the price",
          '',
          spans: [
            TextSpan(text: '${context.t('We take the gold rate from Evolve and apply it to your weight and karat, with no manual adjustment.')} '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: DLink('See how pricing works', onTap: () => context.nav(R.prices)),
            ),
          ],
        ),
        blurb('certificate', 'IGI checks every piece', 'Karat, weight and stones confirmed and guaranteed before settlement.'),
        blurb('lock', 'Money is held until the buyer pays', 'Cash never passes between two people directly.'),
        blurb('file-check', 'Everything is on paper', 'A tax invoice and a full record for both sides, and both sides are identity checked.'),
        blurb(
          'users',
          'We are not the buyer',
          'Dahab holds the money until both sides finish. We do not buy from you, we connect you to a buyer safely. Nothing leaves us before the buyer has paid, except on your first gold sale.',
        ),
      ],
    );
  }
}
