import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../widgets/widgets.dart';

Color? toneColor(Tone t) => switch (t) {
  Tone.ok => DColors.ok,
  Tone.wait => DColors.wait,
  Tone.bad => DColors.bad,
  Tone.warn => DColors.warn,
  Tone.neutral => null,
};

PillKind pillKind(Tone t) => switch (t) {
  Tone.ok => PillKind.ok,
  Tone.wait => PillKind.wait,
  Tone.bad => PillKind.bad,
  Tone.warn => PillKind.warn,
  Tone.neutral => PillKind.wait,
};

/// An order (or listing) card: `.ord-head` followed by content blocks.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.data, this.onAction});

  final OrderCardData data;

  /// Handles this card's buttons instead of [runOrderAction] (live listings).
  final void Function(String action)? onAction;

  void _run(BuildContext context, String action) => onAction != null ? onAction!(action) : runOrderAction(context, action);

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (var i = 0; i < data.blocks.length; i++) {
      final b = data.blocks[i];
      final last = i == data.blocks.length - 1;
      final gap = last ? 0.0 : 11.0;
      blocks.add(
        Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: _block(context, b),
        ),
      );
    }
    return DCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderHead(data: data),
          const Gap(11),
          ...blocks,
        ],
      ),
    );
  }

  Widget _block(BuildContext context, OrderBlock b) {
    switch (b) {
      case RowsBlock(:final rows):
        return DSoft.paper(child: Column(children: [for (final r in rows) _kv(r)]));
      case NoteBlock(:final icon, :final text, :final tone):
        return DNote(icon: icon, text: text, kind: tone == Tone.ok ? NoteKind.ok : (tone == Tone.neutral ? NoteKind.plain : NoteKind.wait));
      case TrackBlock(:final steps):
        return DTrack(
          steps: [
            for (final s in steps)
              DStep(
                s.title,
                s.sub,
                state: switch (s.state) {
                  'done' => TrackState.done,
                  'now' => TrackState.now,
                  _ => TrackState.todo,
                },
                subColor: s.gold ? DColors.gold : null,
                onTap: s.action == null ? null : () => runOrderAction(context, s.action!),
              ),
          ],
        );
      case TextBlock(:final text, :final inset):
        if (inset) {
          return DSoft.paper(
            child: T(text, style: DText.tiny.copyWith(color: DColors.ink2, height: 1.65)),
          );
        }
        return T(text, style: DText.tiny);
      case AmountBlock(:final caption, :final amount, :final rows):
        return DSoft.paper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T(caption, style: DText.tiny),
              Padding(
                padding: const EdgeInsets.only(top: 3, bottom: 6),
                child: T(
                  amount,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: DColors.ok),
                ),
              ),
              for (final r in rows) _kv(r, padding: EdgeInsets.zero),
            ],
          ),
        );
      case ActionsBlock(:final actions):
        if (actions.length == 1) {
          final a = actions.single;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: DButton(a.label, small: true, kind: a.primary ? DButtonKind.primary : DButtonKind.ghost, onTap: () => _run(context, a.action)),
          );
        }
        return DActsRow(
          children: [for (final a in actions) DButton(a.label, small: true, kind: a.primary ? DButtonKind.primary : DButtonKind.ghost, onTap: () => _run(context, a.action))],
        );
    }
  }

  Widget _kv(KV r, {EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 4)}) => DRow(r.k, r.v, valueColor: toneColor(r.tone), rule: r.rule, padding: padding);
}

/// `.ord-head` — thumbnail, title + status pill, role line, "See the piece".
class OrderHead extends StatelessWidget {
  const OrderHead({super.key, required this.data});

  final OrderCardData data;

  @override
  Widget build(BuildContext context) {
    void open() => data.pieceId == null ? context.openPiece(view: data.detailView) : context.openPiece(view: data.detailView, id: data.pieceId!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tappable(
          onTap: open,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: DColors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DColors.line),
            ),
            alignment: Alignment.center,
            child: const DIcon('diamond', size: 22, color: DColors.line2),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and status side by side; on very narrow phones the
              // status drops under the title instead of squeezing it.
              LayoutBuilder(
                builder: (context, c) {
                  final pill = DPill(data.status, kind: pillKind(data.statusTone));
                  final title = T(data.title, style: DText.title);
                  if (c.maxWidth < 200) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const Gap(4), pill]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth * 0.6),
                        child: pill,
                      ),
                    ],
                  );
                },
              ),
              const Gap(3),
              Row(
                children: [
                  if (data.roleIcon != null) ...[DIcon(data.roleIcon!, size: 12, color: DColors.ink3), const SizedBox(width: 4)],
                  Flexible(child: T(data.subtitle, style: DText.tiny)),
                ],
              ),
              const Gap(3),
              DLink('See the piece', onTap: open),
            ],
          ),
        ),
      ],
    );
  }
}

/// What each order/listing button does (the inline `onclick`s).
Future<void> runOrderAction(BuildContext context, String action) async {
  // An order from the API (backend spec 012): open it.
  if (action.startsWith('order:')) return context.nav(R.order, query: {'id': action.substring(6)});
  switch (action) {
    case 'decline':
      final ok = await ask(
        context,
        title: 'Decline this request',
        body: "The buyer's deposit is released and the piece goes back on the market. You can change the making charge again after that.",
        yes: 'Decline',
      );
      if (ok && context.mounted) showToast(context, 'Declined. You can edit the fee now.');
    case 'takedown':
      final ok = await ask(
        context,
        title: 'Take this listing down',
        body: 'It stops showing to buyers. You can put it back up any time, and it keeps its history.',
        yes: 'Take it down',
      );
      if (ok && context.mounted) showToast(context, 'Taken down.');
    case 'relist':
      final ok = await ask(
        context,
        title: 'List it again',
        body: 'We send the piece back to the market at the fee you choose. It stays at IGI until a new buyer collects it.',
        yes: 'List it again',
      );
      if (ok && context.mounted) showToast(context, 'Back on the market.');
    case 'directions':
      showToast(context, 'Directions sent to your phone.');
    case 'accept-toast':
      showToast(context, 'Request accepted. You have 12 working hours to reach IGI.');
    default:
      context.nav(action);
  }
}
