import 'package:flutter/material.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'buttons.dart';
import 'd_icon.dart';
import 'mock_flag.dart';
import 'surfaces.dart';

/// `.menu` row — icon, title with optional sub line, trailing widget
/// (chevron by default).
class DMenu extends StatelessWidget {
  const DMenu({
    super.key,
    required this.title,
    this.sub,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.titleWidget,
    this.subWidget,
    this.mock = false,
  });

  final String title;
  final String? sub;
  final String? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Widget? titleWidget;
  final Widget? subWidget;

  /// Still mock: the hint is made up or it opens a mock screen. Shows a red flag.
  final bool mock;

  @override
  Widget build(BuildContext context) {
    final trail = trailing ?? (showChevron ? const DIcon('chevron-right', size: 16, color: DColors.ink3) : null);
    return Tappable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[SizedBox(width: 20, child: DIcon(icon!, size: 18, color: iconColor ?? DColors.ink2)), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mock && kShowMockFlags)
                    Row(
                      children: [
                        Flexible(child: titleWidget ?? Text(context.t(title), style: const TextStyle(fontSize: 14))),
                        const SizedBox(width: 6),
                        const MockFlag(),
                      ],
                    )
                  else
                    titleWidget ?? Text(context.t(title), style: const TextStyle(fontSize: 14)),
                  if (subWidget != null)
                    subWidget!
                  else if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(context.t(sub!), style: const TextStyle(fontSize: 11, color: DColors.ink3)),
                    ),
                ],
              ),
            ),
            if (trail != null) ...[const SizedBox(width: 12), trail],
          ],
        ),
      ),
    );
  }
}

/// A `.card` with `padding:0 16px` holding `.menu` rows separated by
/// hairlines (`.menu{border-bottom}` / `.menu:last-child{border-bottom:0}`).
class DMenuCard extends StatelessWidget {
  const DMenuCard({super.key, required this.children, this.horizontalPadding = 16, this.margin});

  final List<Widget> children;
  final double horizontalPadding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return DCard(
      margin: margin,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, thickness: 1, color: DColors.line), children[i]],
        ],
      ),
    );
  }
}

/// A single-choice list of `.menu` rows. The chosen row's chevron turns
/// into a green check, like the reason pickers in the prototype.
class DChoiceList<V> extends StatelessWidget {
  const DChoiceList({super.key, required this.options, required this.value, required this.onChanged, this.margin});

  final List<ChoiceOption<V>> options;
  final V? value;
  final ValueChanged<V> onChanged;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return DMenuCard(
      horizontalPadding: 14,
      margin: margin,
      children: [
        for (final o in options)
          DMenu(
            title: o.title,
            sub: o.sub,
            onTap: () => onChanged(o.value),
            trailing: o.value == value ? const DIcon('circle-check', size: 16, color: DColors.ok) : const DIcon('chevron-right', size: 16, color: DColors.ink3),
          ),
      ],
    );
  }
}

class ChoiceOption<V> {
  const ChoiceOption(this.value, this.title, [this.sub]);

  final V value;
  final String title;
  final String? sub;
}

enum TrackState { done, now, todo }

class DStep {
  const DStep(this.title, this.sub, {this.state = TrackState.todo, this.subColor, this.onTap});

  final String title;
  final String sub;
  final TrackState state;
  final Color? subColor;
  final VoidCallback? onTap;
}

/// `.track` — vertical timeline with coloured dots.
class DTrack extends StatelessWidget {
  const DTrack({super.key, required this.steps});

  final List<DStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 4),
      padding: const EdgeInsetsDirectional.only(start: 16),
      decoration: const BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: DColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final s in steps) _StepRow(step: s)],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final DStep step;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (step.state) {
      TrackState.done => DColors.ok,
      TrackState.now => DColors.wait,
      TrackState.todo => DColors.line2,
    };
    return Tappable(
      onTap: step.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: step.state == TrackState.now ? const [BoxShadow(color: DColors.waitBg, spreadRadius: 4)] : null,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(step.title), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(context.t(step.sub), style: TextStyle(fontSize: 11, color: step.subColor ?? DColors.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.slot` — dashed upload tile; solid border and a green check once done.
class DSlot extends StatelessWidget {
  const DSlot({
    super.key,
    required this.title,
    required this.done,
    required this.onTap,
    this.icon = 'camera',
    this.sub,
    this.subColor,
    this.boxHeight = 50,
    this.iconSize = 20,
    this.footer,
  });

  final String title;
  final bool done;
  final VoidCallback onTap;
  final String icon;
  final String? sub;
  final Color? subColor;
  final double boxHeight;
  final double iconSize;

  /// Extra widgets under the title (pills, "Tap to replace").
  final List<Widget>? footer;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRRectPainter(color: done ? DColors.line : DColors.line2, dashed: !done),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            children: [
              Container(
                height: boxHeight,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(color: DColors.paper, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: DIcon(done ? 'circle-check' : icon, size: iconSize, color: done ? DColors.ok : DColors.line2),
              ),
              Text(
                context.t(title),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (sub != null)
                Text(
                  context.t(sub!),
                  textAlign: TextAlign.center,
                  style: DText.tiny.copyWith(color: subColor),
                ),
              ...?footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(DRadius.slot)).deflate(0.5);
    final path = Path()..addRRect(rrect);
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color || old.dashed != dashed;
}

/// `.empty` — centred icon, title, body and an optional action.
class DEmpty extends StatelessWidget {
  const DEmpty({super.key, required this.icon, required this.title, required this.body, this.action, this.onAction});

  final String icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 22),
      child: Column(
        children: [
          DIcon(icon, size: 34, color: DColors.line2),
          const SizedBox(height: 12),
          Text(
            context.t(title),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          Text(
            context.t(body),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: DColors.ink3, height: 1.7),
          ),
          if (action != null) ...[const SizedBox(height: 16), DButton(action!, small: true, onTap: onAction)],
        ],
      ),
    );
  }
}

/// Loading placeholder shown while a mock repository "fetches".
class DLoading extends StatelessWidget {
  const DLoading({super.key, this.height = 160});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.8, color: DColors.gold)),
            const SizedBox(height: 10),
            Text(context.t('Loading…'), style: DText.tiny),
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry button.
class DErrorState extends StatelessWidget {
  const DErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DEmpty(icon: 'alert-triangle', title: 'Something went wrong', body: 'Try again', action: 'Try again', onAction: onRetry);
}

/// FutureBuilder with the prototype's loading / error / empty looks.
class AsyncView<D> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder, this.loadingHeight = 160});

  final Future<D> Function() load;
  final Widget Function(BuildContext context, D data) builder;
  final double loadingHeight;

  @override
  State<AsyncView<D>> createState() => _AsyncViewState<D>();
}

class _AsyncViewState<D> extends State<AsyncView<D>> {
  late Future<D> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<D>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return DErrorState(onRetry: () => setState(() => _future = widget.load()));
        if (!snap.hasData) return DLoading(height: widget.loadingHeight);
        return widget.builder(context, snap.data as D);
      },
    );
  }
}
