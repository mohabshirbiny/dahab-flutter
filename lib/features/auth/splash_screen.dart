import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/live_rates.dart';
import '../../widgets/widgets.dart';

/// `#s-splash` — dark welcome screen with live rates and partners.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>();
    return AppPage(
      id: R.splash,
      padded: false,
      scroll: false,
      child: ColoredBox(
        color: DColors.ink,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // .langtop
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LangPill('English', on: !lang.isArabic, onTap: () => lang.setLang(AppLang.en)),
                          const SizedBox(width: 6),
                          _LangPill('العربية', on: lang.isArabic, onTap: () => lang.setLang(AppLang.ar)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 26, 30, 18),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const DahabLogo(width: 203, height: 58, color: DColors.white),
                            const Gap(16),
                            Text(
                              '${context.t('Sell your jewellery')}\n${context.t("for what it's really worth")}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: DColors.white, fontSize: 22, fontWeight: FontWeight.w500, height: 1.4),
                            ),
                            const Gap(16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: T(
                                'Gold, diamonds, or both together. Priced from the exchange, IGI checks every piece, and your money is held safely until you collect.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: DColors.splashText, fontSize: 13, height: 1.65),
                              ),
                            ),
                            const Gap(16),
                            const _RateCards(),
                            const T(
                              'Prices in EGP per gram, updated live.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: DColors.ink3),
                            ),
                            const Gap(16),
                            const _Partners(),
                          ],
                        ),
                      ),
                    ),
                    // .foot
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
                      child: Column(
                        children: [
                          DButton('Create an account', kind: DButtonKind.light, onTap: () => context.nav(R.signup1)),
                          const Gap(10),
                          DButton('I already have one', kind: DButtonKind.lightGhost, onTap: () => context.nav(R.login)),
                          const Gap(12),
                          DLink(
                            'Look around first',
                            style: const TextStyle(fontSize: 12, color: DColors.ink3),
                            onTap: () {
                              context.enterApp(R.home);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  const _LangPill(this.label, {required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? DColors.gold : DColors.splashLine),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: on ? DColors.white : DColors.ink3)),
      ),
    );
  }
}

/// `.ratecards` — get / pay per gram for each karat, from the live feed.
class _RateCards extends StatelessWidget {
  const _RateCards();

  @override
  Widget build(BuildContext context) {
    final rates = context.watch<LiveRates>();
    if (rates.paused || !rates.ready) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: T(rates.paused ? 'Prices are paused' : 'Loading…', style: const TextStyle(fontSize: 12, color: DColors.ink3)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          for (final k in const [18, 21, 24])
            if (rates.sellersGet(k) != null) ...[
              if (k != 18) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                  decoration: BoxDecoration(color: DColors.splashCard, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      Text(context.t('${k}K'), style: const TextStyle(fontSize: 10, color: DColors.ink3, letterSpacing: 0.4)),
                      const Gap(3),
                      FittedBox(
                        child: Text(
                          context.t('get ${group(rates.rate(k))}'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: DColors.white),
                        ),
                      ),
                      const Gap(2),
                      Text(context.t('pay ${group(rates.buyersPay(k) ?? 0)}'), style: const TextStyle(fontSize: 10, color: DColors.ink3)),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

/// `.partners` — Evolve, IGI, Legal Clinic. The prototype uses text
/// placeholders ("Logos go here once each partner approves the artwork").
class _Partners extends StatelessWidget {
  const _Partners();

  @override
  Widget build(BuildContext context) {
    const partners = [('Evolve', 'Gold pricing'), ('IGI', 'Authentication'), ('Legal Clinic', 'Legal partner')];
    return Column(
      children: [
        const T('Our partners', style: TextStyle(fontSize: 10, color: DColors.ink3)),
        const Gap(9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < partners.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DColors.splashLine),
                      ),
                      child: Text(
                        partners[i].$1,
                        style: const TextStyle(fontFamily: DFonts.serif, fontSize: 11, color: DColors.ink3, letterSpacing: 0.3),
                      ),
                    ),
                    const Gap(5),
                    T(
                      partners[i].$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, color: DColors.splashFaint, letterSpacing: 0.2),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
