import 'package:flutter/material.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'buttons.dart';
import 'd_icon.dart';

/// Translated text. `T('Wallet', style: DText.h3)`.
class T extends StatelessWidget {
  const T(this.text, {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(context.t(text), style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}

/// `.label` — small section heading, 9px below by default.
class DLabel extends StatelessWidget {
  const DLabel(this.text, {super.key, this.bottom = 9, this.top = 0});

  final String text;
  final double bottom;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bottom, top: top),
    child: T(text, style: DText.label),
  );
}

/// `.card` — white, 1px `--line` border, 14px radius.
class DCard extends StatelessWidget {
  const DCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.borderColor, this.onTap, this.margin, this.clip = false});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        decoration: BoxDecoration(
          color: DColors.white,
          borderRadius: BorderRadius.circular(DRadius.card),
          border: Border.all(color: borderColor ?? DColors.line),
        ),
        child: child,
      ),
    );
  }
}

/// `.soft` — 12px radius, 13px padding. White by default; `paper` for the
/// inset grey panels, `bordered` for the frequent `border:1px solid --line`.
class DSoft extends StatelessWidget {
  const DSoft({super.key, required this.child, this.paper = false, this.bordered = false, this.margin, this.padding});

  const DSoft.bordered({super.key, required this.child, this.margin, this.padding}) : paper = false, bordered = true;

  const DSoft.paper({super.key, required this.child, this.margin, this.padding}) : paper = true, bordered = false;

  final Widget child;
  final bool paper;
  final bool bordered;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: paper ? DColors.paper : DColors.white,
        borderRadius: BorderRadius.circular(DRadius.soft),
        border: bordered ? Border.all(color: DColors.line) : null,
      ),
      child: child,
    );
  }
}

enum NoteKind { ok, wait, plain }

/// `.note` — icon + 11px text on a tinted panel.
class DNote extends StatelessWidget {
  const DNote({super.key, required this.icon, this.text, this.spans, this.child, this.kind = NoteKind.plain, this.margin, this.textStyle, this.iconColor});

  /// Arbitrary content instead of text (e.g. key/value rows).
  final Widget? child;

  final String icon;
  final NoteKind kind;

  /// English source string (translated here).
  final String? text;

  /// Rich content instead of [text] — already translated by the caller.
  final List<InlineSpan>? spans;
  final EdgeInsetsGeometry? margin;
  final TextStyle? textStyle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic, border) = switch (kind) {
      NoteKind.ok => (DColors.okBg, DColors.ok, DColors.ok, null),
      NoteKind.wait => (DColors.waitBg, DColors.wait, DColors.wait, null),
      NoteKind.plain => (DColors.white, DColors.ink2, DColors.ink3, Border.all(color: DColors.line)),
    };
    final style = TextStyle(fontSize: 11, height: 1.6, color: fg).merge(textStyle);
    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DRadius.note), border: border),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: DIcon(icon, size: 15, color: iconColor ?? ic),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: child ?? (spans != null ? Text.rich(TextSpan(children: spans), style: style) : Text(context.t(text ?? ''), style: style)),
          ),
        ],
      ),
    );
  }
}

/// `.row` — key on one side, value on the other, 13px.
class DRow extends StatelessWidget {
  const DRow(
    this.k,
    this.v, {
    super.key,
    this.valueWidget,
    this.keyWidget,
    this.rule = false,
    this.bold = false,
    this.keyColor,
    this.valueColor,
    this.valueStyle,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.bottomBorder = false,
    this.onTap,
    this.keyIsLabel = true,
  });

  final String k;
  final String v;
  final Widget? valueWidget;
  final Widget? keyWidget;

  /// `.rule` — top border with 8px/9px spacing.
  final bool rule;

  /// `font-weight:500` on the whole row.
  final bool bold;

  /// `.k` colour (ink-2) unless overridden. When [keyIsLabel] is false the
  /// key uses the ink colour (rows like "Total").
  final Color? keyColor;
  final Color? valueColor;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;
  final bool bottomBorder;
  final VoidCallback? onTap;
  final bool keyIsLabel;

  @override
  Widget build(BuildContext context) {
    final weight = bold ? FontWeight.w500 : FontWeight.w400;
    // `justify-content:space-between`: the value keeps its natural width (up
    // to 55% of the row, then wraps) and the key takes the rest.
    final row = Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, c) => Row(
          children: [
            Expanded(
              child:
                  keyWidget ??
                  Text(
                    context.t(k),
                    style: TextStyle(fontSize: 13, fontWeight: weight, color: keyColor ?? (keyIsLabel ? DColors.ink2 : DColors.ink)),
                  ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.55),
              child:
                  valueWidget ??
                  Text(
                    context.t(v),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 13, fontWeight: weight, color: valueColor ?? DColors.ink).merge(valueStyle),
                  ),
            ),
          ],
        ),
      ),
    );
    Widget out = row;
    if (rule) {
      out = Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.only(top: 5),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: DColors.line)),
        ),
        child: row,
      );
    } else if (bottomBorder) {
      out = DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DColors.line)),
        ),
        child: row,
      );
    }
    return Tappable(onTap: onTap, child: out);
  }
}

enum PillKind { ok, wait, bad, warn, yours }

/// `.pill` — 11px status tag.
class DPill extends StatelessWidget {
  const DPill(this.text, {super.key, this.kind = PillKind.ok, this.icon});

  final String text;
  final PillKind kind;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.ok => (DColors.okBg, DColors.ok),
      PillKind.wait => (DColors.waitBg, DColors.wait),
      PillKind.bad => (DColors.badBg, DColors.bad),
      PillKind.warn => (DColors.warnBg, DColors.warn),
      PillKind.yours => (DColors.yoursBg, DColors.gold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[DIcon(icon!, size: 11, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(context.t(text), style: TextStyle(fontSize: 11, color: fg, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// `.chip` — rounded filter chip.
class DChip extends StatelessWidget {
  const DChip(this.label, {super.key, this.on = false, this.onTap, this.leadingIcon});

  final String label;
  final bool on;
  final VoidCallback? onTap;
  final String? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final color = on ? DColors.ink : DColors.ink2;
    return Tappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: DColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? DColors.ink : DColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[DIcon(leadingIcon!, size: 12, color: color), const SizedBox(width: 4)],
            Text(
              context.t(label),
              style: TextStyle(fontSize: 12, color: color, fontWeight: on ? FontWeight.w500 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.chips` — wrapping row of chips, 6px apart.
class DChips extends StatelessWidget {
  const DChips({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: children);
}

/// `.seg` — segmented control; the selected option is filled with ink.
class DSeg<V> extends StatelessWidget {
  const DSeg({super.key, required this.options, required this.value, required this.onChanged, this.fontSize = 13});

  final List<(V, String)> options;
  final V value;
  final ValueChanged<V> onChanged;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _SegButton(label: options[i].$2, on: options[i].$1 == value, fontSize: fontSize, onTap: () => onChanged(options[i].$1)),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.kindgrid` — three-column grid of segment buttons.
class DKindGrid<V> extends StatelessWidget {
  const DKindGrid({super.key, required this.options, required this.value, required this.onChanged});

  final List<(V, String)> options;
  final V value;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 3;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              SizedBox(
                width: w,
                child: _SegButton(label: o.$2, on: o.$1 == value, fontSize: 12, onTap: () => onChanged(o.$1), horizontalPad: 4),
              ),
          ],
        );
      },
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({required this.label, required this.on, required this.onTap, required this.fontSize, this.horizontalPad = 2});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final double fontSize;
  final double horizontalPad;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(vertical: 9, horizontal: horizontalPad),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? DColors.ink : DColors.white,
          borderRadius: BorderRadius.circular(DRadius.seg),
          border: Border.all(color: on ? DColors.ink : DColors.line),
        ),
        child: Text(
          context.t(label),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: fontSize, color: on ? DColors.white : DColors.ink, fontWeight: on ? FontWeight.w500 : FontWeight.w400),
        ),
      ),
    );
  }
}

/// Check-mark bullet line used in "Before you continue", the guest gate,
/// the weight guide and the close-account data card.
class DCheckLine extends StatelessWidget {
  const DCheckLine(this.text, {super.key, this.bottom = 8, this.icon = 'circle-check', this.iconColor = DColors.ok});

  final String text;
  final double bottom;
  final String icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DIcon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 9),
          Expanded(child: T(text, style: DText.muted12)),
        ],
      ),
    );
  }
}

/// A "soft" row with a gold icon and a bold title + tiny description
/// (the "How you're protected" list and the price source cards).
class DIconBlurb extends StatelessWidget {
  const DIconBlurb({super.key, required this.icon, required this.title, this.body, this.bodySpans, this.iconSize = 18, this.titleSize = 13});

  final String icon;
  final String title;
  final String? body;
  final List<InlineSpan>? bodySpans;
  final double iconSize;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: DIcon(icon, size: iconSize, color: DColors.gold),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T(
                title,
                style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w500),
              ),
              if (body != null || bodySpans != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: bodySpans != null ? Text.rich(TextSpan(children: bodySpans), style: DText.tiny) : T(body!, style: DText.tiny),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain vertical gap — keeps screen code close to the prototype's margins.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}
