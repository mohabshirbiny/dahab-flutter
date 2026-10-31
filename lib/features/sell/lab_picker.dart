import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/labs.dart';
import '../../core/text/keys/offer_details.dart';
import '../../core/text/texts_controller.dart';
import '../../models/reference.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/branch_sheet.dart';

/// "Which certificate do you have?": one button per lab, then another lab and no certificate.
class CertificateChoice extends StatelessWidget {
  const CertificateChoice({super.key, required this.labs});

  final List<LabRef> labs;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<SellDraft>();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final lab in labs)
          DChip(
            lab.name(context.isArabic),
            on: d.cert == 'lab' && d.certificateLabId == lab.id,
            onTap: () => d.update((d) {
              d.cert = 'lab';
              d.certificateLabId = lab.id;
            }),
          ),
        DChip(context.k(LabKeys.anotherLab), on: d.cert == 'other', onTap: () => d.update((d) => d.cert = 'other')),
        DChip(context.k(LabKeys.noCertificate), on: d.cert == 'none', onTap: () => d.update((d) => d.cert = 'none')),
      ],
    );
  }
}

/// The labs and their branches in one list: the seller chooses one branch. Each lab shows what it
/// costs for this piece, and the lab behind the seller's certificate is marked recommended.
class LabPicker extends StatelessWidget {
  const LabPicker({super.key, required this.labs});

  final List<LabRef> labs;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<SellDraft>();
    if (labs.isEmpty) return DNote(icon: 'info-circle', kind: NoteKind.wait, text: context.k(LabKeys.none));
    return LabBranchList(
      labs: labs,
      selectedBranchId: d.branchIds.isEmpty ? null : d.branchIds.first,
      recommendedLabId: d.type.name != 'gold' && d.cert == 'lab' ? d.certificateLabId : null,
      costOf: (lab) => d.costLabel(context, lab),
      onBranch: (lab, branch) => d.chooseBranch(lab.id, branch.id),
    );
  }
}

/// The list itself, also used when a seller chooses again for a piece already listed.
class LabBranchList extends StatelessWidget {
  const LabBranchList({
    super.key,
    required this.labs,
    required this.selectedBranchId,
    required this.onBranch,
    this.recommendedLabId,
    this.costOf,
  });

  final List<LabRef> labs;
  final int? selectedBranchId;
  final int? recommendedLabId;
  final void Function(LabRef lab, BranchRef branch) onBranch;

  /// "Certificate cost: 700"; null shows nothing, as for a gold cost of 0.
  final String? Function(LabRef lab)? costOf;

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final lab in labs) ...[
          DCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(lab.name(arabic), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    if (lab.id == recommendedLabId) Text(context.k(LabKeys.recommended), style: DText.tiny.copyWith(color: DColors.ok, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (costOf?.call(lab) case final cost?) ...[const Gap(2), Text(cost, style: DText.tiny)],
                const Gap(8),
                for (final b in lab.branches) ...[
                  DCheck(
                    value: selectedBranchId == b.id,
                    bottom: 2,
                    onChanged: (_) => onBranch(lab, b),
                    text: arabic && b.nameAr.isNotEmpty ? b.nameAr : b.nameEn,
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 25, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((arabic ? b.addressAr : b.addressEn).isNotEmpty) Text(arabic ? b.addressAr : b.addressEn, style: DText.tiny),
                        for (final line in hoursLines(context, b)) Text(line, style: DText.tiny),
                        DLink(context.k(OfferDetailsKeys.branchDetails), onTap: () => showBranchDetails(context, b)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(10),
        ],
      ],
    );
  }
}

/// A branch's week in small type: days in a row with the same hours on one line.
List<String> hoursLines(BuildContext context, BranchRef b) {
  String of(int dow) => [for (final h in b.hours.where((h) => h.dow == dow)) '${h.opensAt}–${h.closesAt}'].join(', ');
  final lines = <String>[];
  var dow = 0;
  while (dow < 7) {
    final same = of(dow);
    var end = dow;
    while (end + 1 < 7 && of(end + 1) == same) {
      end++;
    }
    if (same.isNotEmpty) {
      final first = context.k(OfferDetailsKeys.days[dow]);
      lines.add(end == dow ? '$first: $same' : '$first – ${context.k(OfferDetailsKeys.days[end])}: $same');
    }
    dow = end + 1;
  }
  return lines;
}
