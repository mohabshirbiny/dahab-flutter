import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/listing_price.dart';
import '../../core/text/keys/screens_shared.dart';
import '../../core/text/texts_controller.dart';
import '../../core/utils/idempotency.dart';
import '../../models/listing.dart';
import '../../models/piece.dart';
import '../../models/prices.dart';
import '../../services/api/api_client.dart';
import '../../services/live_rates.dart';
import '../../services/pricing.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';

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

/// `#s-editprice` — change the price of a live piece (backend spec 022): the making charge of
/// gold, the asking price of a stone. One field; "You would receive" is the backend's quote.
class EditPriceScreen extends StatefulWidget {
  const EditPriceScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<EditPriceScreen> createState() => _EditPriceScreenState();
}

class _EditPriceScreenState extends State<EditPriceScreen> {
  final _figure = TextEditingController();
  Listing? _listing;
  Object? _loadError;
  bool _busy = false;
  String? _error;

  /// One key per attempt at one figure, so a retried tap is replayed, not repeated.
  String? _key;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _figure.dispose();
    super.dispose();
  }

  bool get _gold => _listing?.category == 'gold';

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final l = await context.read<ListingsRepository>().show(widget.listingId);
      if (mounted) setState(() => _listing = l);
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  /// The typed figure, or null when it is not a number with at most two decimals.
  String? get _typed {
    final text = _figure.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text)) return null;
    final v = double.parse(text);
    if (!_gold && v <= 0) return null;
    return text;
  }

  QuoteParams? get _params {
    final l = _listing;
    final typed = _typed;
    if (l == null || typed == null) return null;
    final v = double.parse(typed);
    final weight = double.tryParse(l.weight ?? '') ?? 0;
    final params = switch (l.category) {
      'gold' => QuoteParams(type: SellType.gold, karat: l.karat, weight: weight, makingPerGram: v),
      'diamond' => QuoteParams(type: SellType.diamond, askingPrice: v),
      _ => QuoteParams(type: SellType.mixed, karat: l.karat, weight: weight, askingPrice: v),
    };
    return params.askable ? params : null;
  }

  String _message(ApiException e) {
    final field = _gold ? 'making_charge_per_g' : 'asking_price';
    return switch (e.code) {
      'listing_has_requests' => context.kr(ListingPriceKeys.errHasRequests),
      'listing_price_locked' => context.kr(ListingPriceKeys.errLocked),
      'listing_not_live' => context.kr(ListingPriceKeys.errNotLive),
      'platform_stopped' => controlRefusalMessage(e) ?? context.kr(ListingPriceKeys.errStopped),
      'validation_failed' when e.fieldError(field) == 'This is already the price.' => context.kr(ListingPriceKeys.same),
      'validation_failed' => context.kr(ListingPriceKeys.amountInvalid),
      _ => listingErrorMessage(e),
    };
  }

  Future<void> _save() async {
    final typed = _typed;
    final l = _listing;
    if (_busy || l == null) return;
    if (typed == null) return setState(() => _error = context.kr(ListingPriceKeys.amountInvalid));
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {_gold ? 'making_charge_per_g' : 'asking_price': typed};
      await context.read<ListingsRepository>().changePrice(l.id, body, idempotencyKey: _key ??= newIdempotencyKey());
      _key = null;
      if (!mounted) return;
      showToast(context, context.kr(ListingPriceKeys.saved));
      context.back();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!e.isNetwork) _key = null;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _listing;
    final gold = _gold;
    final title = gold || l == null ? context.k(ScreensSharedKeys.sharedChangeMakingCharge) : context.k(ListingPriceKeys.titleStones);
    if (l == null) {
      return AppPage(
        id: R.editprice,
        title: title,
        child: _loadError == null
            ? const DLoading(height: 300)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(context.k(ListingPriceKeys.loadFailed), style: DText.muted),
                  const Gap(12),
                  DButton.ghost('Try again', small: true, onTap: _load),
                ],
              ),
      );
    }
    final piece = PieceDetail.fromListing(l).piece;
    final pieceTitle = context.isArabic && piece.titleAr != null ? piece.titleAr! : piece.title;
    final current = gold ? l.makingPerGram : l.askingPrice;
    final quote = _params == null ? null : context.watch<LiveRates>().quote(_params!);
    return AppPage(
      id: R.editprice,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DNote(icon: 'info-circle', text: context.k(ListingPriceKeys.note)),
          const Gap(14),
          DLabel(pieceTitle, bottom: 12),
          DRow(
            context.k(gold ? ListingPriceKeys.makingNow : ListingPriceKeys.askingNow),
            gold ? '${moneyOf(current)} /g' : moneyOf(current),
          ),
          const Gap(12),
          DField(
            label: context.k(gold ? ListingPriceKeys.makingLabel : ListingPriceKeys.askingLabel),
            error: _error,
            child: DInput(
              controller: _figure,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {
                _error = null;
                _key = null;
              }),
            ),
          ),
          DSoft.bordered(
            child: DRow(
              '',
              '',
              keyWidget: T(context.k(ListingPriceKeys.youWouldReceive), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              valueWidget: quote == null
                  ? T(_typed == null ? '—' : context.k(ListingPriceKeys.estimatePaused), style: DText.tiny)
                  : T(money(quote.net), style: DText.price),
            ),
          ),
          const Gap(16),
          DButton(context.k(ListingPriceKeys.save), loading: _busy, onTap: _save),
        ],
      ),
    );
  }
}
