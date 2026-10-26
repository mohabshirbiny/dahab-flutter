import '../text_key.dart';

/// Owner notes of 2026-10-26 (backend `docs/features/app-notes-sales.md`): what the seller will
/// receive before the buyer pays, a top-up still waiting to be matched on the pay screen, and a
/// free relist of a stone piece capped at what the buyer paid. `order.estimate.*`,
/// `order.pay.pending_topups.*`, `order.free_relist.form.previous_price|error_price_above_paid`,
/// `wallet.sale_paid.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class AppNotesSalesKeys {
  static const _area = 'Orders';
  static const _estimate = 'Order: what the seller receives';
  static const _pay = 'Order: pay the balance';
  static const _relist = 'Relist with no commission';

  // ---- The seller's money before the buyer pays ----

  static const estimateTitle = TextKey('order.estimate.title', 'What you will receive', ar: 'اللي هيوصلك', area: _area, where: _estimate);
  static const estimatePiece = TextKey('order.estimate.piece', 'The sale price', ar: 'سعر البيع', area: _area, where: _estimate);
  static const estimateSaving = TextKey('order.estimate.saving', 'Saved on the commission', ar: 'وفّرت من العمولة', area: _area, where: _estimate);
  static const estimateCertificate = TextKey('order.estimate.certificate', 'IGI certificate', ar: 'شهادة IGI', area: _area, where: _estimate);
  static const estimateReceive = TextKey('order.estimate.receive', 'You receive', ar: 'هتستلم', area: _area, where: _estimate);
  static const estimateStated = TextKey(
    'order.estimate.stated',
    'An estimate on the weight you stated. The final figure follows the weight IGI measures.',
    ar: 'ده تقدير على الوزن اللي كتبته. الرقم النهائي بيتحسب على الوزن اللي IGI بتقيسه.',
    area: _area,
    where: _estimate,
  );
  static const estimateIndicative = TextKey(
    'order.estimate.indicative',
    'An estimate. It is fixed once the piece passes inspection.',
    ar: 'ده تقدير. بيتثبت أول ما القطعة تعدّي الفحص.',
    area: _area,
    where: _estimate,
  );
  static const estimateFinal = TextKey(
    'order.estimate.final',
    'This reaches your wallet as soon as the buyer pays the balance.',
    ar: 'المبلغ ده بيوصل محفظتك أول ما المشتري يدفع الباقي.',
    area: _area,
    where: _estimate,
  );

  // ---- A top-up the buyer sent that Dahab has not matched yet ----

  static const pendingTopUpsTitle = TextKey('order.pay.pending_topups.title', 'Waiting for Dahab to confirm', ar: 'مستني تأكيد دهب', area: _area, where: _pay);
  static const pendingTopUpsNote = TextKey(
    'order.pay.pending_topups.note',
    'You told us about a transfer. Once Dahab matches it, it is added to your wallet and you can pay from here.',
    ar: 'إنت بلغتنا بتحويل. أول ما دهب تطابقه، هيتضاف لمحفظتك وتقدر تدفع من هنا.',
    area: _area,
    where: _pay,
  );

  // ---- A free relist of a stone piece ----

  static const relistPreviousPrice = TextKey(
    'order.free_relist.form.previous_price',
    'You paid {price} EGP for this piece. The new price can be the same or lower, not higher.',
    ar: 'إنت دفعت {price} جنيه في القطعة دي. السعر الجديد لازم يبقى زيه أو أقل، مش أكتر.',
    placeholders: ['price'],
    area: _area,
    where: _relist,
  );
  static const relistErrorAbovePaid = TextKey(
    'order.free_relist.form.error_price_above_paid',
    'The price can not be more than what you paid ({price} EGP).',
    ar: 'السعر مينفعش يبقى أكتر من اللي دفعته ({price} جنيه).',
    placeholders: ['price'],
    area: _area,
    where: _relist,
  );

  static const all = <TextKey>[
    estimateTitle,
    estimatePiece,
    estimateSaving,
    estimateCertificate,
    estimateReceive,
    estimateStated,
    estimateIndicative,
    estimateFinal,
    pendingTopUpsTitle,
    pendingTopUpsNote,
    relistPreviousPrice,
    relistErrorAbovePaid,
  ];
}
