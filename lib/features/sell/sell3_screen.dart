import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/promo.dart';
import '../../core/text/texts_controller.dart';
import '../../models/promo.dart';
import '../../models/reference.dart';
import '../../services/api/api_client.dart';
import '../../services/api/market_api.dart';
import '../../services/live_rates.dart';
import '../../services/repositories.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';
import '../shared/piece_card.dart';
import 'promo_card.dart';

/// `#s-sell3` — review, payout timeline, ownership confirmation.
class Sell3Screen extends StatefulWidget {
  const Sell3Screen({super.key});

  @override
  State<Sell3Screen> createState() => _Sell3ScreenState();
}

class _Sell3ScreenState extends State<Sell3Screen> {
  bool _own = false;
  String? _error;
  bool _busy = false;
  int _reload = 0;

  /// The advance asked without a code: a seller's first sale of a gold piece is paid ahead
  /// automatically while the backend's switch is on. A failure just shows nothing.
  PaysAdvance? _autoAdvance;
  String? _autoFor;

  void _checkAdvance(SellDraft d) {
    final signature = d.quoteParams.query;
    if (_autoFor == signature) return;
    _autoFor = signature;
    context.read<PromoRepository>().preview(d.quoteParams).then((p) {
      if (mounted && _autoFor == signature) setState(() => _autoAdvance = p.paysAdvance);
    }, onError: (Object _) {});
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
    final promos = context.read<PromoRepository>();
    try {
      await draft.send(listings, await reference.sellReference(), promos: promos);
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
    final q = d.quote(context.watch<LiveRates>());
    // Paid ahead only when the backend says this sale qualifies and can be advanced now (spec 023):
    // through the applied code, or with no code for a seller's first gold sale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAdvance(d);
    });
    final advance = d.promoPreview?.paysAdvance ?? _autoAdvance;
    final paidAhead = advance != null && advance.available;
    return AppPage(
      id: R.sell3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Step 3 of 3', style: DText.tiny),
          const Gap(14),
          DCard(
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
                      if (q == null)
                        const T('Prices are paused right now.', style: DText.tiny)
                      else ...[
                        T(money(q.net + d.promoSaving), style: DText.price),
                        const Gap(3),
                        const T('is what reaches your wallet if it sells today', style: DText.tiny),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          const DLabel('Before it goes live'),
          DSoft.bordered(
            child: Column(
              children: [
                const DRow('Listing fee', 'None'),
                const DRow('Inspection cost', 'Paid by Dahab'),
                if (paidAhead) ...[
                  const DRow('Money released (first gold sale)', 'When IGI confirms the piece'),
                  const DRow('Money released (after that)', 'When the buyer pays'),
                ] else
                  DRow(context.k(PromoKeys.releasedLabel), context.t('When the buyer pays')),
              ],
            ),
          ),
          const Gap(14),
          const PromoCard(),
          const Gap(14),
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
          // Spec 023: said only when the backend confirms it, and honestly when it cannot be paid early.
          if (advance != null)
            DNote(
              icon: paidAhead ? 'circle-check' : 'info-circle',
              kind: paidAhead ? NoteKind.ok : NoteKind.wait,
              text: paidAhead
                  ? context.k(PromoKeys.advanceAvailable, {'cap': moneyOf(advance.capEgp)})
                  : context.k(advance.reason == 'not_first_gold' ? PromoKeys.advanceNotFirstGold : PromoKeys.advanceUnavailable),
            ),
          if (advance != null) const Gap(12),
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

/// `#s-weight` — how to find the real weight (the typical-weights list was removed).
class WeightGuideScreen extends StatelessWidget {
  const WeightGuideScreen({super.key});

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
