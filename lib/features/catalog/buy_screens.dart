import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/piece.dart';
import '../../services/app_session.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/piece_card.dart';

/// `#s-saved`
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.saved,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T("Saved pieces don't lock a price. Send a request when you're ready.", style: DText.tiny),
          const Gap(12),
          AsyncView<List<Piece>>(
            load: context.read<CatalogRepository>().saved,
            builder: (context, items) => items.isEmpty
                ? DEmpty(
                    icon: 'heart',
                    title: 'Nothing here yet',
                    body: "Saved pieces don't lock a price. Send a request when you're ready.",
                    action: 'Keep looking',
                    onAction: () => context.nav(R.browse),
                  )
                : Grid2(children: [for (final p in items) PieceCard(piece: p)]),
          ),
        ],
      ),
    );
  }
}

/// `#s-gate` — guests must sign up before buying or selling.
class GateScreen extends StatelessWidget {
  const GateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.gate,
      padded: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
        child: Column(
          children: [
            const DIcon('lock', size: 34, color: DColors.gold),
            const Gap(14),
            const T('One step before you buy', style: DText.h2, textAlign: TextAlign.center),
            const Gap(8),
            const T('Buying and selling on Dahab needs a verified account. It is what keeps both sides safe.', style: DText.muted, textAlign: TextAlign.center),
            const Gap(22),
            const DCard(
              child: Column(
                children: [
                  DCheckLine('Takes about two minutes'),
                  DCheckLine('Nothing is charged until you send a request'),
                  DCheckLine('The piece you were looking at will be waiting', bottom: 0),
                ],
              ),
            ),
            const Gap(18),
            DButton('Create an account', onTap: () => context.nav(R.signup1)),
            const Gap(9),
            DButton.ghost('I already have one', onTap: () => context.nav(R.login)),
            const Gap(14),
            DLink('Keep looking around', style: DText.tiny, onTap: context.back),
          ],
        ),
      ),
    );
  }
}

/// Shared layout of the two centred result screens.
class _ResultLayout extends StatelessWidget {
  const _ResultLayout({required this.icon, required this.iconColor, required this.title, required this.sub, required this.children, this.iconSize = 34});

  final String icon;
  final Color iconColor;
  final double iconSize;
  final String title;
  final String sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
      child: Column(
        children: [
          DIcon(icon, size: iconSize, color: iconColor),
          const Gap(14),
          T(title, style: DText.h2, textAlign: TextAlign.center),
          const Gap(6),
          T(sub, style: DText.muted, textAlign: TextAlign.center),
          const Gap(20),
          ...children,
        ],
      ),
    );
  }
}

/// `#s-reqsent` — the request just sent (backend spec 011), from [AppSession.lastRequest].
class RequestSentScreen extends StatelessWidget {
  const RequestSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppSession>().lastRequest;
    final arabic = context.isArabic;
    final place = r?.placeInLine;
    final ahead = r?.aheadCount ?? 0;
    return AppPage(
      id: R.reqsent,
      padded: false,
      child: _ResultLayout(
        icon: 'circle-check',
        iconColor: DColors.ok,
        title: 'Your request is with the seller',
        sub: r == null ? '' : '${arabic ? r.pieceTitleAr : r.pieceTitleEn} · ${moneyOf(r.lockedTotalPrice)}',
        children: [
          if (r != null)
            DCard(
              child: Column(
                children: [
                  DRow('Held from your wallet', moneyOf(r.depositAmount), valueStyle: const TextStyle(fontWeight: FontWeight.w500)),
                  if (place != null) DRow('Your place in the queue', ahead == 0 ? '${ordinal(place)}, next to be answered' : '${ordinal(place)}, $ahead ahead of you'),
                  DRow('The seller replies before', whenOf(r.sellerReplyDeadline)),
                  DRow('Your price is fixed at', moneyOf(r.lockedTotalPrice), rule: true),
                ],
              ),
            ),
          const Gap(14),
          const DNote(
            icon: 'info-circle',
            text: 'If the seller declines, misses the deadline, or takes a buyer ahead of you, the hold comes off straight away and nothing is charged.',
          ),
          const Gap(16),
          DButton('Follow your order', onTap: () => context.nav(R.orders)),
          const Gap(9),
          DButton.ghost('Keep looking', onTap: () => context.nav(R.browse)),
        ],
      ),
    );
  }
}

/// `#s-topup` — the wallet doesn't cover the deposit; the figures come from the
/// backend's 409 `insufficient_funds` (spec 011), kept in [AppSession.shortfall].
class TopUpFirstScreen extends StatelessWidget {
  const TopUpFirstScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSession>().shortfall;
    return AppPage(
      id: R.topup,
      padded: false,
      child: _ResultLayout(
        icon: 'wallet',
        iconColor: DColors.gold,
        iconSize: 32,
        title: 'You need a little more',
        sub: 'A deposit is held from your wallet when you send a request.',
        children: [
          if (s != null)
            DCard(
              child: Column(
                children: [
                  DRow('Deposit needed', moneyOf(s.depositAmount)),
                  DRow('In your wallet', moneyOf(s.available)),
                  DRow(
                    'Add at least',
                    moneyOf(s.shortfall),
                    rule: true,
                    valueColor: DColors.wait,
                    valueStyle: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const Gap(14),
          const DNote(icon: 'info-circle', text: 'Other buyers may be in the queue for this piece, and the price follows the gold rate until you send your request.'),
          const Gap(16),
          DButton('Add funds', onTap: () => context.nav(R.addfunds)),
          const Gap(9),
          DButton.ghost(
            'Save it for later',
            onTap: () {
              showToast(context, 'Saved. You will find it under saved pieces.');
              Future.delayed(const Duration(milliseconds: 700), () {
                if (context.mounted) context.nav(R.saved);
              });
            },
          ),
        ],
      ),
    );
  }
}

/// `#s-report` — report a listing.
class ReportListingScreen extends StatefulWidget {
  const ReportListingScreen({super.key});

  @override
  State<ReportListingScreen> createState() => _ReportListingScreenState();
}

class _ReportListingScreenState extends State<ReportListingScreen> {
  int? _reason;
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.report,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DCard(
            padding: EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T('Gold ring, 21K', style: DText.title),
                Gap(3),
                T('Seller 4417', style: DText.tiny),
              ],
            ),
          ),
          const Gap(16),
          const DLabel('What looks wrong?'),
          DChoiceList<int>(
            value: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              _error = false;
            }),
            options: const [
              ChoiceOption(1, 'The photos look fake or taken from somewhere else'),
              ChoiceOption(2, 'The price or the weight looks wrong'),
              ChoiceOption(3, 'The description does not match the photos'),
              ChoiceOption(4, 'I think this piece is not theirs to sell'),
              ChoiceOption(5, 'The seller is trying to deal outside Dahab'),
              ChoiceOption(6, 'Something else'),
            ],
          ),
          const Gap(14),
          const DLabel('Anything to add'),
          const DInput(maxLines: 3, hint: 'Optional, but it helps us look faster.'),
          const Gap(14),
          const DNote(icon: 'lock', text: 'The seller is never told who reported the listing.'),
          const Gap(14),
          DError('Choose what looks wrong first.', visible: _error, top: 0),
          if (_error) const Gap(7),
          DButton(
            'Send report',
            onTap: () async {
              if (_reason == null) return setState(() => _error = true);
              await tell(context, title: 'Thanks', body: 'We are looking at this listing. The seller is not told who reported it.');
              if (context.mounted) context.back();
            },
          ),
        ],
      ),
    );
  }
}
