import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/offer_details.dart';
import '../../core/text/texts_controller.dart';
import '../../models/promo.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';

/// The buyer's promo code on the piece page (owner request 2026-10-26), laid out like the seller's on the
/// sell form: type it, Apply, and see what it takes off — the price, the discount, what you pay and the
/// deposit — before sending the request. The backend checks it and records nothing by asking; the applied
/// code goes with the buy request ([code]).
class BuyerCodeCard extends StatefulWidget {
  const BuyerCodeCard({super.key, required this.listingId, required this.code});

  final String listingId;

  /// The applied code, read when the request is sent; null when none.
  final ValueNotifier<String?> code;

  @override
  State<BuyerCodeCard> createState() => _BuyerCodeCardState();
}

class _BuyerCodeCardState extends State<BuyerCodeCard> {
  final _c = TextEditingController();
  BuyerCodePreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _c.text.trim().toUpperCase();
    if (code.isEmpty) return;
    if (!context.read<AuthController>().isSignedIn) return context.nav(R.gate);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await context.read<BuyRequestsRepository>().previewCode(listingId: widget.listingId, code: code);
      if (!mounted) return;
      widget.code.value = p.code;
      setState(() => _preview = p);
    } on ApiException catch (e) {
      if (!mounted) return;
      widget.code.value = null;
      setState(() {
        _preview = null;
        _error = buyRequestErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove() {
    widget.code.value = null;
    _c.clear();
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return DCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DLabel(context.k(OfferDetailsKeys.buyCodeTitle), bottom: 8),
          Row(
            children: [
              Expanded(
                child: DInput(controller: _c, hint: 'GOLD10', uppercase: true),
              ),
              const SizedBox(width: 8),
              if (p != null)
                DButton.ghost(context.k(OfferDetailsKeys.buyCodeRemove), small: true, onTap: _remove)
              else
                DButton.ghost(context.k(OfferDetailsKeys.buyCodeApply), small: true, loading: _busy, onTap: _apply),
            ],
          ),
          const Gap(8),
          if (_error != null)
            T(_error!, style: DText.tiny.copyWith(color: DColors.bad))
          else if (p != null) ...[
            if (p.effect == 'spread') Text(context.k(OfferDetailsKeys.buyCodeSellerPrice), style: DText.tiny.copyWith(color: DColors.ok)),
            if (p.hasDiscount) ...[
              DRow(context.k(OfferDetailsKeys.price), moneyOf(p.priceBefore)),
              DRow(context.k(OfferDetailsKeys.discount, {'code': p.code}), '− ${moneyOf(p.discount)}', keyColor: DColors.ok, valueColor: DColors.ok),
              DRow(context.k(OfferDetailsKeys.buyCodeYouPay), moneyOf(p.total), rule: true, bold: true, keyIsLabel: false),
            ] else if (!p.lowersDeposit)
              Text(context.k(OfferDetailsKeys.buyCodeNoDiscount), style: DText.tiny),
            if (p.lowersDeposit) ...[
              DRow(context.k(OfferDetailsKeys.depositFull), moneyOf(p.depositFull)),
              DRow(
                context.k(OfferDetailsKeys.depositDiscount, {'code': p.code}),
                '− ${moneyOf(_minus(p.depositFull, p.deposit))}',
                keyColor: DColors.ok,
                valueColor: DColors.ok,
              ),
            ],
            DRow(context.k(OfferDetailsKeys.buyCodeDeposit), moneyOf(p.deposit)),
            const Gap(4),
            Text(context.k(OfferDetailsKeys.buyCodeApplied), style: DText.tiny.copyWith(color: DColors.ok)),
            Text(context.k(OfferDetailsKeys.indicative), style: DText.tiny),
          ] else
            Text(context.k(OfferDetailsKeys.buyCodeHint), style: DText.tiny),
        ],
      ),
    );
  }

  /// The backend's two figures differ by the deposit discount; shown to the piastre.
  static String _minus(String a, String b) => ((double.tryParse(a) ?? 0) - (double.tryParse(b) ?? 0)).toStringAsFixed(2);
}
