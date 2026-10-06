import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/piece.dart';
import '../../services/api/api_client.dart';
import '../../services/app_session.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../account/account_messages.dart';
import '../shared/piece_card.dart';

/// `#s-saved` — pieces the customer saved (backend spec 017 FR-040).
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _reload = 0;

  Future<void> _remove(SavedPiece s) async {
    try {
      await context.read<AccountRepository>().unsave(s.listingId);
      if (!mounted) return;
      setState(() => _reload++);
      showToast(context, 'Removed from saved.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, accountErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.saved,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T("Saved pieces don't lock a price. Send a request when you're ready.", style: DText.tiny),
          const Gap(12),
          AsyncView<List<SavedPiece>>(
            key: ValueKey(_reload),
            load: context.read<AccountRepository>().saved,
            builder: (context, items) {
              if (items.isEmpty) {
                return DEmpty(
                  icon: 'heart',
                  title: 'Nothing here yet',
                  body: "Saved pieces don't lock a price. Send a request when you're ready.",
                  action: 'Keep looking',
                  onAction: () => context.nav(R.browse),
                );
              }
              final live = [
                for (final s in items)
                  if (s.piece != null) s.piece!,
              ];
              final gone = [
                for (final s in items)
                  if (!s.available) s,
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (live.isNotEmpty) Grid2(children: [for (final p in live) PieceCard(piece: p)]),
                  if (gone.isNotEmpty) ...[
                    const Gap(16),
                    const DLabel('No longer available'),
                    DMenuCard(
                      children: [
                        for (final g in gone)
                          DMenu(
                            icon: 'heart',
                            title: g.title,
                            sub: [if (g.karat != null) '${g.karat}K', if (g.weight != null) '${g.weight} g'].join(', '),
                            trailing: DLink(
                              'Remove',
                              style: const TextStyle(fontSize: 12, color: DColors.bad),
                              onTap: () => _remove(g),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
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
                  DRow('Held from your wallet', moneyOf(r.depositHeld ?? r.depositAmount), valueStyle: const TextStyle(fontWeight: FontWeight.w500)),
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

/// `#s-report` — report a listing (backend spec 017 FR-052). The seller is never told who.
class ReportListingScreen extends StatefulWidget {
  const ReportListingScreen({super.key, required this.listingId, this.title});

  final String listingId;
  final String? title;

  @override
  State<ReportListingScreen> createState() => _ReportListingScreenState();
}

class _ReportListingScreenState extends State<ReportListingScreen> {
  String? _reason;
  String? _error;
  bool _busy = false;
  String? _key;
  final _note = TextEditingController();

  static const _reasons = [
    ChoiceOption('photos_not_genuine', 'The photos look fake or taken from somewhere else'),
    ChoiceOption('price_or_weight_wrong', 'The price or the weight looks wrong'),
    ChoiceOption('description_mismatch', 'The description does not match the photos'),
    ChoiceOption('not_theirs_to_sell', 'I think this piece is not theirs to sell'),
    ChoiceOption('off_platform_dealing', 'The seller is trying to deal outside Dahab'),
    ChoiceOption('other', 'Something else'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) return setState(() => _error = 'Choose what looks wrong first.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _key ??= newIdempotencyKey();
      final note = _note.text.trim();
      await context.read<AccountRepository>().report(listingId: widget.listingId, reason: _reason!, note: note.isEmpty ? null : note, idempotencyKey: _key!);
      _key = null;
      if (!mounted) return;
      await tell(context, title: 'Thanks', body: 'We are looking at this listing. The seller is not told who reported it.');
      if (mounted) context.back();
    } on ApiException catch (e) {
      if (e.code != 'network_error') _key = null;
      if (mounted) setState(() => _error = accountErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.report,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null && widget.title!.isNotEmpty) ...[
            DCard(
              padding: const EdgeInsets.all(13),
              child: T(widget.title!, style: DText.title),
            ),
            const Gap(16),
          ],
          const DLabel('What looks wrong?'),
          DChoiceList<String>(
            value: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              _error = null;
            }),
            options: _reasons,
          ),
          const Gap(14),
          const DLabel('Anything to add'),
          DInput(controller: _note, maxLines: 3, hint: 'Optional, but it helps us look faster.'),
          const Gap(14),
          const DNote(icon: 'lock', text: 'The seller is never told who reported the listing.'),
          const Gap(14),
          DError(_error ?? '', visible: _error != null, top: 0),
          if (_error != null) const Gap(7),
          DButton('Send report', loading: _busy, onTap: _send),
        ],
      ),
    );
  }
}
