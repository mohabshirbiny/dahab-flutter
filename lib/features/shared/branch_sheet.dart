import 'package:flutter/material.dart';

import '../../core/text/keys/offer_details.dart';
import '../../core/text/texts_controller.dart';
import '../../models/reference.dart';
import '../../services/media_tab.dart';
import '../../widgets/widgets.dart';

/// A branch's details (owner note 2026-10-25): its address, its hours day by day, its phone and a
/// map link, all as staff set them on the Dashboard (`GET /reference/branches`, the order's `branch`).
Future<void> showBranchDetails(BuildContext context, BranchRef branch) {
  return showDialog<void>(
    context: context,
    barrierColor: DColors.modalBarrier,
    builder: (_) => _BranchDialog(branch: branch),
  );
}

/// The branch's name with a "Hours and address" link under it, for a list of branches.
class BranchName extends StatelessWidget {
  const BranchName({super.key, required this.branch, this.style});

  final BranchRef branch;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(arabic && branch.nameAr.isNotEmpty ? branch.nameAr : branch.nameEn, style: style ?? DText.body14),
        DLink(context.k(OfferDetailsKeys.branchDetails), onTap: () => showBranchDetails(context, branch)),
      ],
    );
  }
}

class _BranchDialog extends StatelessWidget {
  const _BranchDialog({required this.branch});

  final BranchRef branch;

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    final b = branch;
    final address = arabic && b.addressAr.isNotEmpty ? b.addressAr : b.addressEn;
    return Dialog(
      backgroundColor: DColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DRadius.modal)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(arabic && b.nameAr.isNotEmpty ? b.nameAr : b.nameEn, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (address.isNotEmpty) ...[const Gap(12), DLabel(context.k(OfferDetailsKeys.branchAddress), bottom: 4), Text(address, style: DText.muted)],
              const Gap(12),
              DLabel(context.k(OfferDetailsKeys.branchHours), bottom: 4),
              if (b.hours.isEmpty)
                Text(context.k(OfferDetailsKeys.branchNoHours), style: DText.muted)
              else
                for (var dow = 0; dow < 7; dow++) DRow(context.k(OfferDetailsKeys.days[dow]), _hoursOf(context, dow)),
              if (b.contactPhone != null) ...[
                const Gap(12),
                DRow(
                  context.k(OfferDetailsKeys.branchPhone),
                  '',
                  valueWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: SelectableText(b.contactPhone!, style: DText.body13),
                      ),
                      const SizedBox(width: 10),
                      DLink(context.k(OfferDetailsKeys.branchCall), onTap: () => MediaTab.open(Uri.parse('tel:${b.contactPhone!.replaceAll(' ', '')}'))),
                    ],
                  ),
                ),
              ],
              if (b.mapUrl != null) ...[
                const Gap(14),
                DButton.ghost(context.k(OfferDetailsKeys.branchMap), small: true, onTap: () => MediaTab.open(Uri.tryParse(b.mapUrl!))),
              ],
              const Gap(16),
              DButton('OK', onTap: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }

  /// "10:00–14:00, 16:00–20:00", or "Closed".
  String _hoursOf(BuildContext context, int dow) {
    final lines = [for (final h in branch.hours.where((h) => h.dow == dow)) '${h.opensAt}–${h.closesAt}'];
    return lines.isEmpty ? context.k(OfferDetailsKeys.branchClosed) : lines.join(', ');
  }
}
