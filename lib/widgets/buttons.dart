import 'package:flutter/material.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';

enum DButtonKind {
  /// `.btn` — ink background, white text.
  primary,

  /// `.btn.ghost` — transparent, 1px `--line-2` border.
  ghost,

  /// `.btn` with `background:var(--bad)` (close account).
  danger,

  /// `.splash .btn` — white background on the dark splash.
  light,

  /// `.splash .btn.ghost` — white text, dark border.
  lightGhost,
}

/// `.btn` and its variants. Labels are English source strings and are
/// translated here.
class DButton extends StatefulWidget {
  const DButton(this.label, {super.key, this.onTap, this.kind = DButtonKind.primary, this.small = false, this.expand, this.loading = false, this.foreground, this.borderColor});

  const DButton.ghost(this.label, {super.key, this.onTap, this.small = false, this.expand, this.loading = false, this.foreground, this.borderColor}) : kind = DButtonKind.ghost;

  final String label;
  final VoidCallback? onTap;
  final DButtonKind kind;

  /// `.btn.small` / `.btn.tiny-b` — 10×14 padding, 13px, auto width.
  final bool small;

  /// Full width. Defaults to `!small`, like the CSS.
  final bool? expand;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Overrides for the "Saved" toggle state.
  final Color? foreground;
  final Color? borderColor;

  @override
  State<DButton> createState() => _DButtonState();
}

class _DButtonState extends State<DButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (widget.kind) {
      DButtonKind.primary => (DColors.ink, DColors.white, DColors.ink),
      DButtonKind.ghost => (Colors.transparent, DColors.ink, DColors.line2),
      DButtonKind.danger => (DColors.bad, DColors.white, DColors.bad),
      DButtonKind.light => (DColors.white, DColors.ink, DColors.white),
      DButtonKind.lightGhost => (Colors.transparent, DColors.white, DColors.splashGhostBorder),
    };
    final foreground = widget.foreground ?? fg;
    final enabled = widget.onTap != null && !widget.loading;
    final expand = widget.expand ?? !widget.small;

    final label = widget.loading
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.8, color: foreground))
        : Text(
            context.t(widget.label),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: widget.small ? 13 : 14, fontWeight: FontWeight.w500, color: foreground),
          );

    Widget box = AnimatedScale(
      scale: _down ? 0.99 : 1,
      duration: const Duration(milliseconds: 60),
      child: Container(
        width: expand ? double.infinity : null,
        constraints: BoxConstraints(minHeight: widget.small ? 38 : 45),
        padding: widget.small ? const EdgeInsets.symmetric(vertical: 9, horizontal: 14) : const EdgeInsets.all(12),
        alignment: expand ? Alignment.center : null,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DRadius.button),
          border: Border.all(color: widget.borderColor ?? border),
        ),
        child: expand
            ? label
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Flexible(child: label)],
              ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: context.t(widget.label),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: enabled ? widget.onTap : null,
          child: Opacity(opacity: widget.onTap == null && !widget.loading ? 0.45 : 1, child: box),
        ),
      ),
    );
  }
}

/// `.acts-row` — buttons share the row equally, 8px apart.
class DActsRow extends StatelessWidget {
  const DActsRow({super.key, required this.children, this.gap = 8});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: children[i])],
        ],
      ),
    );
  }
}

/// Small tappable text link (gold by default), e.g. "See all".
class DLink extends StatelessWidget {
  const DLink(this.text, {super.key, required this.onTap, this.style, this.textAlign});

  final String text;
  final VoidCallback onTap;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          context.t(text),
          textAlign: textAlign,
          style: style ?? const TextStyle(fontSize: 11, color: DColors.gold, height: 1.55),
        ),
      ),
    );
  }
}

/// Generic tap target with a pointer cursor, for cards and rows.
class Tappable extends StatelessWidget {
  const Tappable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child),
    );
  }
}
