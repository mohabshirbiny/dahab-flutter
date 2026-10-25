import 'package:flutter/material.dart';

import '../../core/text/keys/offer_details.dart';
import '../../core/text/texts_controller.dart';
import '../../models/stone.dart';
import '../../widgets/widgets.dart';

/// A stone piece's certificate and the stone as its seller states it (owner note 2026-10-25): the
/// seller and the buyer both see when a piece comes without a certificate, and what the stone is.
/// Nothing for gold (no [stone]).
List<Widget> stoneRows(
  BuildContext context,
  StoneDetails? stone, {
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 4),
  bool bottomBorder = false,
}) {
  final s = stone;
  if (s == null) return const [];
  final cut = switch (s.cut) {
    'excellent' => context.k(OfferDetailsKeys.cutExcellent),
    'very_good' => context.k(OfferDetailsKeys.cutVeryGood),
    'good' => context.k(OfferDetailsKeys.cutGood),
    _ => null,
  };
  return [
    if (s.certificateKind != null)
      DRow(
        context.k(OfferDetailsKeys.certificate),
        certificateWords(context, s.certificateKind!),
        valueColor: s.hasNoCertificate ? DColors.wait : null,
        padding: padding,
        bottomBorder: bottomBorder,
      ),
    if (s.carat != null) DRow(context.k(OfferDetailsKeys.stoneWeight), '${_trim(s.carat!)} ct', padding: padding, bottomBorder: bottomBorder),
    if (s.clarity != null) DRow(context.k(OfferDetailsKeys.clarity), s.clarity!.toUpperCase(), padding: padding, bottomBorder: bottomBorder),
    if (cut != null) DRow(context.k(OfferDetailsKeys.cut), cut, padding: padding, bottomBorder: bottomBorder),
    if (s.describesStone) ...[const Gap(4), Text(context.k(OfferDetailsKeys.stated), style: DText.tiny)],
    if (s.hasNoCertificate) ...[const Gap(8), DNote(icon: 'certificate', kind: NoteKind.wait, text: context.k(OfferDetailsKeys.certNoneNote))],
  ];
}

/// "IGI certificate" · "Another lab's certificate" · "No certificate".
String certificateWords(BuildContext context, String kind) => switch (kind) {
  'igi' => context.k(OfferDetailsKeys.certIgi),
  'other_lab' => context.k(OfferDetailsKeys.certOther),
  _ => context.k(OfferDetailsKeys.certNone),
};

/// The seller's row for what IGI's certificate costs them, by what they bring.
String certificateFeeLabel(BuildContext context, String? kind) => switch (kind) {
  'none' => context.k(OfferDetailsKeys.feeNone),
  'other_lab' => context.k(OfferDetailsKeys.feeOther),
  _ => context.k(OfferDetailsKeys.feeIgi),
};

/// "0.70" → "0.7", "1.00" → "1".
String _trim(String carat) {
  final v = double.tryParse(carat);
  if (v == null) return carat;
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
