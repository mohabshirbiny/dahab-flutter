import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/promo.dart';
import '../../core/text/texts_controller.dart';
import '../../models/promo.dart';
import '../../services/api/api_client.dart';
import '../../services/repositories.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';

/// The promo code card of the sell form (backend spec 023 Story 2). One widget for steps 1 and 3.
///
/// *Apply* asks the backend what the code would do; asking records nothing. The code is recorded on
/// the listing when it is created. The figures are the backend's: the card never computes a
/// commission. With no code, it still tells the seller of a commission credit already waiting.
class PromoCard extends StatefulWidget {
  const PromoCard({super.key});

  @override
  State<PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<PromoCard> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;
  PromoPreview? _pool;

  /// The piece the last answer was for; a change re-asks, so the saving never goes stale.
  String? _signature;

  @override
  void initState() {
    super.initState();
    final draft = context.read<SellDraft>();
    _c.text = draft.promoCode ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkPool();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// A credit the seller already has (the inviter's reward), shown before any code is typed.
  Future<void> _checkPool() async {
    final draft = context.read<SellDraft>();
    if (draft.promoCode != null) return;
    try {
      final p = await context.read<PromoRepository>().preview(draft.quoteParams);
      if (mounted) setState(() => _pool = p.hasWaiver && p.saved > 0 ? p : null);
    } catch (_) {
      // The pool is a courtesy: no answer is not an error on the form.
    }
  }

  Future<void> _apply() async {
    final draft = context.read<SellDraft>();
    final code = _c.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.kr(PromoKeys.cardEnterFirst));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await context.read<PromoRepository>().preview(draft.quoteParams, code: code);
      if (!mounted) return;
      _signature = draft.quoteParams.query;
      draft.update((d) {
        d.promoCode = p.code ?? code.toUpperCase();
        d.promoPreview = p;
      });
      setState(() => _busy = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _refusal(e);
      });
    }
  }

  void _remove() {
    context.read<SellDraft>().update((d) {
      d.promoCode = null;
      d.promoPreview = null;
    });
    setState(() {
      _c.clear();
      _error = null;
    });
    _checkPool();
  }

  /// Re-asks the backend when the piece changed under a code that was applied.
  Future<void> _refresh(SellDraft draft) async {
    final code = draft.promoCode;
    if (code == null) return;
    _signature = draft.quoteParams.query;
    try {
      final p = await context.read<PromoRepository>().preview(draft.quoteParams, code: code);
      if (mounted) draft.update((d) => d.promoPreview = p);
    } on ApiException catch (e) {
      if (!mounted) return;
      draft.update((d) {
        d.promoCode = null;
        d.promoPreview = null;
      });
      setState(() => _error = _refusal(e));
    }
  }

  String _refusal(ApiException e) {
    if (e.code == 'promo_code_invalid') {
      final reason = (e.extra['details'] as Map?)?['reason'];
      final key = switch (reason) {
        'not_started' => PromoKeys.errNotStarted,
        'ended' => PromoKeys.errEnded,
        'first_sale_only' => PromoKeys.errFirstSaleOnly,
        'already_used' => PromoKeys.errAlreadyUsed,
        'cap_reached' => PromoKeys.errCapReached,
        'not_open' => PromoKeys.errNotOpen,
        'own_referral' => PromoKeys.errOwnReferral,
        'referral_joined' => PromoKeys.errReferralJoined,
        'referral_full' => PromoKeys.errReferralFull,
        'device_limit' => PromoKeys.errDeviceLimit,
        _ => PromoKeys.errUnknown,
      };
      return context.kr(key);
    }
    if (e.code == 'listing_promo_locked') return context.kr(PromoKeys.errLocked);
    return e.message.isNotEmpty ? e.message : context.kr(PromoKeys.errUnknown);
  }

  /// What the applied code does, in the app's words and with the backend's figures.
  List<String> _effect(BuildContext context, PromoPreview p) {
    final lines = <String>[];
    lines.add(switch (p.mode) {
      'waive' => context.k(PromoKeys.resultWaive),
      'percent' => context.k(PromoKeys.resultPercent, {'percent': _trim(p.percent)}),
      _ => context.k(PromoKeys.resultAmount, {'amount': moneyOf(p.savedEgp)}),
    });
    if (p.floorApplied) lines.add(context.k(PromoKeys.resultMinimum, {'minimum': _trim(p.minimumEgp)}));
    if (p.firstSaleOnly) lines.add(context.k(PromoKeys.resultFirstSaleOnly));
    return lines;
  }

  static String _trim(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null) return v ?? '';
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<SellDraft>();
    final applied = draft.promoCode != null;

    // The piece moved under an applied code: ask again, once.
    if (applied && _signature != null && _signature != draft.quoteParams.query && !_busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh(draft);
      });
    }

    final preview = draft.promoPreview;
    return DCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DLabel(context.k(PromoKeys.cardTitle), bottom: 8),
          Row(
            children: [
              Expanded(child: DInput(controller: _c, hint: 'WELCOME', uppercase: true)),
              const SizedBox(width: 8),
              if (applied)
                DButton.ghost(context.k(PromoKeys.cardRemove), small: true, onTap: _remove)
              else
                DButton.ghost(context.k(PromoKeys.cardApply), small: true, loading: _busy, onTap: _apply),
            ],
          ),
          const Gap(8),
          if (_error != null)
            T(_error!, style: DText.tiny.copyWith(color: DColors.bad))
          else if (applied && preview != null) ...[
            for (final line in _effect(context, preview)) T(line, style: DText.tiny.copyWith(color: DColors.ok)),
            T(context.k(PromoKeys.resultApplied), style: DText.tiny),
          ] else if (_pool != null)
            T(context.k(PromoKeys.resultCreditWaiting, {'amount': moneyOf(_pool!.savedEgp)}), style: DText.tiny.copyWith(color: DColors.ok))
          else
            T(context.k(PromoKeys.cardHint), style: DText.tiny),
        ],
      ),
    );
  }
}
