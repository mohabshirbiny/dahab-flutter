import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';
import '../shared/piece_card.dart';

/// `#s-sell2` — photos, optional video, description.
class Sell2Screen extends StatefulWidget {
  const Sell2Screen({super.key});

  @override
  State<Sell2Screen> createState() => _Sell2ScreenState();
}

class _Sell2ScreenState extends State<Sell2Screen> {
  late final _desc = TextEditingController(text: context.read<SellDraft>().description);
  String? _error;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _continue() {
    final d = context.read<SellDraft>();
    if (d.requiredAdded < d.requiredCount) return setState(() => _error = 'Add the required photos before continuing.');
    if (_desc.text.trim().length < 40) return setState(() => _error = 'Add a little more detail before continuing.');
    setState(() => _error = null);
    context.nav(R.sell3);
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<SellDraft>();
    return AppPage(
      id: R.sell2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Step 2 of 3', style: DText.tiny),
          const Gap(14),
          const DNote(icon: 'info-circle', text: 'IGI will compare your piece against what you upload. What you show is what you hand over.'),
          const Gap(15),
          const DNote(
            icon: 'arrow-up-right',
            kind: NoteKind.ok,
            text: 'Clear photos and a short video help your piece sell faster and at a better price. It only takes a few minutes.',
          ),
          const Gap(14),
          DSoft.bordered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DLabel('How to shoot', bottom: 8),
                for (final (icon, text, last) in const [
                  ('square', 'White background, a sheet of paper works', false),
                  ('sun', 'Daylight near a window, no flash', false),
                  ('wand-off', 'No filters, no editing', true),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : 6),
                    child: Row(
                      children: [
                        DIcon(icon, size: 14, color: DColors.ink3),
                        const SizedBox(width: 9),
                        Expanded(child: T(text, style: DText.muted12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Gap(15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: T('Photos', style: DText.label)),
              T('${d.requiredAdded} of ${d.requiredCount} required added', style: DText.tiny),
            ],
          ),
          const Gap(9),
          Grid2(
            children: [for (final s in d.photoSlots) _PhotoSlot(slot: s, done: d.has(s.key), onTap: () => pickIntoSlot(context, s.key))],
          ),
          const Gap(9),
          DButton.ghost(
            'Add another photo',
            small: true,
            onTap: () {
              if (!d.addExtraPhoto()) showToast(context, 'Six photos is plenty.');
            },
          ),
          const Gap(10),
          const DNote(
            icon: 'receipt',
            text: 'Adding the original invoice builds buyer confidence. It stays private and is only shared with the buyer after the purchase is complete.',
          ),
          const Gap(12),
          const DNote(
            icon: 'alert-triangle',
            kind: NoteKind.wait,
            text: "Wear, scratches or a missing stone must be visible. Damage you don't show cancels the sale at inspection.",
          ),
          const Gap(15),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: T('Short video', style: DText.label)),
              T('Optional', style: DText.tiny),
            ],
          ),
          const Gap(9),
          DSlot(
            title: 'Record 10 to 15 seconds',
            sub: 'Turn the piece slowly so every side shows',
            icon: 'video',
            boxHeight: 56,
            iconSize: 24,
            done: d.has('video'),
            onTap: () => pickIntoSlot(context, 'video'),
          ),
          const Gap(8),
          T('Pieces with a video sell noticeably faster.', style: DText.tiny.copyWith(color: DColors.ok)),
          const Gap(15),
          const DLabel('Description'),
          DInput(
            controller: _desc,
            maxLines: 4,
            hint: '21K gold ring, worn twice, small scratch on the inner band. Bought 2021, box included.',
            onChanged: (v) {
              d.description = v;
              setState(() => _error = null);
            },
          ),
          const Gap(6),
          Row(
            children: [
              const Expanded(child: T('Say the condition plainly. It protects you.', style: DText.tiny)),
              T('${_desc.text.trim().length} of 40', style: DText.tiny),
            ],
          ),
          DError(_error ?? '', visible: _error != null),
          const Gap(12),
          DButton('Continue to review', onTap: _continue),
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.slot, required this.done, required this.onTap});

  final PhotoSlot slot;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DSlot(
      title: slot.title,
      icon: slot.icon,
      done: done,
      onTap: onTap,
      footer: [
        const Gap(4),
        if (done)
          DPill(slot.required ? 'Required, added' : 'Added', kind: PillKind.ok)
        else if (slot.required)
          const DPill('Required', kind: PillKind.wait)
        else
          T(slot.hint == null ? 'Optional' : 'Optional, ${slot.hint!.toLowerCase()}', style: DText.tiny),
        if (done) ...[const Gap(2), const T('Tap to replace', style: DText.linkTiny)],
      ],
    );
  }
}
