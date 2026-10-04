import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reference.dart';
import '../../services/api/api_client.dart';
import '../../services/api/market_api.dart';
import '../../services/app_session.dart';
import '../../services/live_rates.dart';
import '../../services/repositories.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';
import '../shared/piece_card.dart';

/// `#s-sell3` — review, payout timeline, ownership confirmation.
class Sell3Screen extends StatefulWidget {
  const Sell3Screen({super.key});

  @override
  State<Sell3Screen> createState() => _Sell3ScreenState();
}

class _Sell3ScreenState extends State<Sell3Screen> {
  final _promo = TextEditingController();
  String? _promoMsg;
  bool _promoOk = false;
  bool _own = false;
  String? _error;
  bool _busy = false;
  int _reload = 0;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  void _applyPromo() {
    final draft = context.read<SellDraft>();
    final code = _promo.text.trim();
    final p = code.isEmpty ? null : context.read<ContentRepository>().promo(code);
    draft.update((d) => d.promo = p);
    setState(() {
      _promoOk = p != null;
      _promoMsg = p != null ? '${context.tr(p.label)} ${context.tr('applied.')}' : (code.isEmpty ? 'Enter a code first.' : 'That code is not valid or has expired.');
    });
  }

  /// Uploads the files, creates (or edits) the listing and sends it for
  /// review (backend spec 010). A retry after a failure repeats nothing.
  Future<void> _send() async {
    final draft = context.read<SellDraft>();
    if (draft.requiredAdded < draft.requiredCount) return setState(() => _error = 'Add the required photos before continuing.');
    if (draft.description.trim().length < 40) return setState(() => _error = 'Add a little more detail before continuing.');
    if (draft.branchIds.isEmpty) return setState(() => _error = 'Choose at least one branch you can bring the piece to.');
    if (!_own) return setState(() => _error = 'Confirm ownership to list the piece.');
    setState(() {
      _busy = true;
      _error = null;
    });
    final reference = context.read<ReferenceRepository>();
    final listings = context.read<ListingsRepository>();
    try {
      await draft.send(listings, await reference.sellReference());
      if (!mounted) return;
      draft.reset();
      setState(() => _busy = false);
      await tell(
        context,
        title: 'Sent for approval',
        body: 'We are checking your photos and description. You will hear back within a few hours, and we may ask for a clearer photo.',
      );
      if (mounted) context.nav(R.listings);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'upload_token_invalid') draft.forgetTokens();
      final stale = e.code == 'validation_failed' && (e.fieldError('ownership_legal_doc_id') != null || e.fieldErrors.keys.any((k) => k.startsWith('branch_option_ids')));
      if (stale && reference is ApiReferenceRepository) reference.refresh();
      setState(() {
        _busy = false;
        _error = listingErrorMessage(e);
        if (stale) {
          // The text or the branches changed: show the current ones and ask again.
          _own = false;
          _reload++;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<SellDraft>();
    final q = d.quote(d.rateFor(context.watch<LiveRates>()));
    final showStats = context.watch<AppSession>().payStatsVisible;
    return AppPage(
      id: R.sell3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Step 3 of 3', style: DText.tiny),
          const Gap(14),
          MockMark(
            child: DCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PieceThumb(),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        T(money(q.net), style: DText.price),
                        const Gap(3),
                        const T('is what reaches your wallet if it sells today', style: DText.tiny),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          const DLabel('Before it goes live'),
          const DSoft.bordered(
            child: Column(
              children: [
                DRow('Listing fee', 'None'),
                DRow('Inspection cost', 'Paid by Dahab'),
                DRow('Money released (first gold sale)', 'When Dahab receives the piece'),
                DRow('Money released (after that)', 'When the buyer pays'),
              ],
            ),
          ),
          const Gap(14),
          const DLabel('Have a promo code?'),
          Row(
            children: [
              Expanded(
                child: DInput(controller: _promo, hint: 'e.g. DAHAB50', uppercase: true),
              ),
              const SizedBox(width: 9),
              DButton('Apply', small: true, onTap: _applyPromo),
            ],
          ),
          const Gap(8),
          if (_promoMsg != null) ...[T(_promoMsg!, style: TextStyle(fontSize: 12, color: _promoOk ? DColors.ok : DColors.bad)), const Gap(14)] else const Gap(6),
          const DNote(
            icon: 'clock',
            text: 'We check your photos and description before the piece goes live. Usually within a few hours. We may ask for a clearer photo or a fuller description.',
          ),
          const Gap(12),
          const DNote(
            icon: 'clock',
            kind: NoteKind.wait,
            text: "Once it is live and a buyer's request is accepted, you have 12 working hours to bring the piece to IGI. You can ask for more time with a reason.",
          ),
          const Gap(12),
          const DLabel('When your money reaches you'),
          const DCard(
            child: DTrack(
              steps: [
                DStep('The piece reaches IGI', 'Within 12 working hours of the seller accepting', state: TrackState.done),
                DStep('The buyer pays the balance', 'They have up to 10 days', state: TrackState.done),
                DStep('The money lands in your wallet', 'All of it, in full, once the buyer pays'),
                DStep('You withdraw to your bank', 'Within one working day'),
              ],
            ),
          ),
          const Gap(12),
          if (showStats) ...[
            const DSoft.bordered(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DRow('Money usually reaches sellers in', '4 days'),
                  DRow('Sales that complete', '92%'),
                  Gap(7),
                  T('From our own record of completed sales, updated automatically.', style: DText.tiny),
                ],
              ),
            ),
            const Gap(12),
          ],
          DNote(
            icon: 'circle-check',
            kind: NoteKind.ok,
            spans: [
              TextSpan(
                text: context.t('This is your first sale, so you are paid differently.'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text:
                    ' ${context.t('For gold, the full amount reaches your wallet as soon as Dahab receives your piece, before the buyer pays. From your second sale on, and for anything with diamonds, the money comes the moment the buyer pays the balance.')}',
              ),
            ],
          ),
          const Gap(12),
          const DNote(
            icon: 'shield-check',
            text: 'If the buyer does not pay within the deadline, your piece comes back to you and you keep 50% of their deposit, as compensation for your time and the trip.',
          ),
          const Gap(12),
          const DNote(
            icon: 'info-circle',
            text:
                'If IGI finds a different weight or karat, we tell the buyer and they decide. You can leave the piece at IGI and go, and we will tell you the result. If the buyer declines, the piece goes back on the market at the corrected weight and Dahab covers the second inspection.',
          ),
          const Gap(14),
          // The branches and the declaration text come from the backend.
          AsyncView<SellReference>(
            key: ValueKey(_reload),
            load: context.read<ReferenceRepository>().sellReference,
            loadingHeight: 120,
            builder: (context, ref) {
              d.syncWith(ref);
              final arabic = context.isArabic;
              final text = arabic && ref.declaration.bodyAr.isNotEmpty ? ref.declaration.bodyAr : ref.declaration.bodyEn;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DLabel('Where can you bring the piece?'),
                  const T('Choose every branch that suits you. The buyer picks one of them.', style: DText.tiny),
                  const Gap(8),
                  if (ref.branches.isEmpty)
                    const DNote(icon: 'info-circle', kind: NoteKind.wait, text: 'No branch is open for inspections right now. Try again later.')
                  else
                    for (final b in ref.branches)
                      DCheck(
                        value: d.branchIds.contains(b.id),
                        onChanged: (_) {
                          d.toggleBranch(b.id);
                          setState(() => _error = null);
                        },
                        text: arabic && b.nameAr.isNotEmpty ? b.nameAr : b.nameEn,
                      ),
                  const Gap(10),
                  DCheck(
                    value: _own,
                    bottom: 8,
                    onChanged: (v) => setState(() {
                      _own = v;
                      _error = null;
                    }),
                    text: text.isEmpty ? 'I confirm this piece is mine to sell and the details above are accurate.' : text,
                  ),
                ],
              );
            },
          ),
          DError(_error ?? '', visible: _error != null),
          const Gap(12),
          DButton('Send for approval', loading: _busy, onTap: _send),
        ],
      ),
    );
  }
}

/// `#s-weight` — typical weights; picking one sets the weight slider.
class WeightGuideScreen extends StatelessWidget {
  const WeightGuideScreen({super.key});

  static const _guide = [
    ('Plain ring', 'Usually 3 to 5 g', 4),
    ('Ring with a stone', 'Usually 4 to 7 g', 6),
    ('Pair of earrings', 'Usually 3 to 6 g', 4),
    ('Chain or necklace', 'Usually 8 to 15 g', 11),
    ('Bangle', 'Usually 15 to 30 g', 20),
    ('Bridal set', 'Usually 25 to 45 g', 30),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.weight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(
            icon: 'alert-triangle',
            kind: NoteKind.wait,
            text: 'A guess is only a starting point. Buyers compare on price, so a piece listed at the wrong weight usually sits unsold or gets adjusted at inspection.',
          ),
          const Gap(16),
          const DLabel('Typical weights'),
          DMenuCard(
            children: [
              for (final (title, sub, w) in _guide)
                DMenu(
                  title: title,
                  sub: sub,
                  trailing: T('Use $w g', style: DText.linkTiny),
                  onTap: () {
                    context.read<SellDraft>().update((d) => d.weight = w.toDouble());
                    showToast(context, 'Set to $w g. Change it if you find the real weight.');
                    Future.delayed(const Duration(milliseconds: 700), () {
                      if (context.mounted) context.nav(R.sell1);
                    });
                  },
                ),
            ],
          ),
          const Gap(14),
          const DLabel('Better than a guess'),
          const DCard(
            child: Column(
              children: [
                DCheckLine('A kitchen scale at home reads to 1 gram, usually close enough.', bottom: 9),
                DCheckLine('Any pharmacy or jeweller will weigh it for you in a minute, for nothing.', bottom: 9),
                DCheckLine('Your original invoice usually has the weight and the karat on it.', bottom: 0),
              ],
            ),
          ),
          const Gap(14),
          const T('IGI weighs the piece before settlement either way. If the real weight differs, the price is adjusted and both sides are told.', style: DText.tiny),
        ],
      ),
    );
  }
}
