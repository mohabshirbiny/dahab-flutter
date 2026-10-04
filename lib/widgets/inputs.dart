import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'buttons.dart';
import 'd_icon.dart';

InputDecoration _decoration(BuildContext context, {String? hint, Widget? suffix, EdgeInsets? padding}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(DRadius.input),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    isDense: true,
    hintText: hint == null ? null : context.t(hint),
    hintStyle: const TextStyle(color: DColors.ink3, fontSize: 14, height: 1.6),
    filled: true,
    fillColor: DColors.white,
    contentPadding: padding ?? const EdgeInsets.all(12),
    border: border(DColors.line),
    enabledBorder: border(DColors.line),
    focusedBorder: border(DColors.ink),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
    counterText: '',
  );
}

/// `.field` — label above an input, 13px bottom margin.
class DField extends StatelessWidget {
  const DField({super.key, required this.label, required this.child, this.bottom = 13, this.hint, this.error});

  final String label;
  final Widget child;
  final double bottom;

  /// `.tiny` helper line under the input.
  final String? hint;

  /// `.err` line under the input (e.g. a server validation message).
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(label), style: const TextStyle(fontSize: 12, color: DColors.ink2)),
          const SizedBox(height: 6),
          child,
          if (error != null) DError(error!, visible: true),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(context.t(hint!), style: DText.tiny),
            ),
        ],
      ),
    );
  }
}

/// `input[type=text|email|tel|password]` and `textarea`.
class DInput extends StatefulWidget {
  const DInput({
    super.key,
    this.controller,
    this.hint,
    this.password = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.initialValue,
    this.uppercase = false,
    this.textAlign,
    this.inputFormatters,
    this.textDirection,
    this.onSubmitted,
    this.autofillHints,
  });

  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextEditingController? controller;
  final String? hint;
  final bool password;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final bool uppercase;
  final TextAlign? textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final TextDirection? textDirection;

  @override
  State<DInput> createState() => _DInputState();
}

class _DInputState extends State<DInput> {
  late final TextEditingController _c = widget.controller ?? TextEditingController(text: widget.initialValue);
  bool _obscure = true;

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffix;
    if (widget.password) {
      suffix = Tappable(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Semantics(
          label: context.t(_obscure ? 'Show password' : 'Hide password'),
          button: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DIcon(_obscure ? 'eye' : 'eye-off', size: 17, color: DColors.ink3),
          ),
        ),
      );
    }
    return TextField(
      controller: _c,
      obscureText: widget.password && _obscure,
      obscuringCharacter: '•',
      keyboardType: widget.keyboardType ?? (widget.maxLines > 1 ? TextInputType.multiline : null),
      maxLines: widget.password ? 1 : widget.maxLines,
      minLines: widget.maxLines > 1 ? widget.maxLines : null,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      textAlign: widget.textAlign ?? TextAlign.start,
      textDirection: widget.textDirection,
      textCapitalization: widget.uppercase ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: [if (widget.uppercase) _UpperCaseFormatter(), ...?widget.inputFormatters],
      cursorColor: DColors.ink,
      cursorWidth: 1.2,
      style: const TextStyle(fontSize: 14, height: 1.6, color: DColors.ink),
      decoration: _decoration(context, hint: widget.hint, suffix: suffix),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Native-looking `<select>`, styled like the inputs.
class DSelect<V> extends StatelessWidget {
  const DSelect({super.key, required this.options, required this.value, required this.onChanged, this.translateLabels = true});

  final List<(V, String)> options;
  final V value;
  final ValueChanged<V> onChanged;
  final bool translateLabels;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<V>(
      initialValue: value,
      isExpanded: true,
      icon: const Padding(
        padding: EdgeInsets.only(left: 4),
        child: RotatedBox(quarterTurns: 1, child: DIcon('chevron-right', size: 14, color: DColors.ink2)),
      ),
      dropdownColor: DColors.white,
      borderRadius: BorderRadius.circular(DRadius.input),
      style: const TextStyle(fontSize: 14, color: DColors.ink, fontFamilyFallback: ['Noto Color Emoji']),
      decoration: _decoration(context, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11)),
      items: [
        for (final o in options)
          DropdownMenuItem<V>(
            value: o.$1,
            child: Text(translateLabels ? context.t(o.$2) : o.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Checkbox + 12px muted text (`label > input[type=checkbox] + span.muted`).
class DCheck extends StatelessWidget {
  const DCheck({super.key, required this.value, required this.onChanged, required this.text, this.bottom = 6});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Tappable(
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Semantics(
                checked: value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: value ? DColors.ink : DColors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: value ? DColors.ink : DColors.ink3),
                  ),
                  child: value ? const Icon(Icons.check, size: 12, color: DColors.white) : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(context.t(text), style: DText.muted12)),
          ],
        ),
      ),
    );
  }
}

/// `.err` — inline validation message, hidden until [visible].
class DError extends StatelessWidget {
  const DError(this.text, {super.key, required this.visible, this.top = 7});

  final String text;
  final bool visible;
  final double top;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Text(context.t(text), style: const TextStyle(fontSize: 12, color: DColors.bad)),
    );
  }
}

/// `.slider` — label, range input, value.
class DSlider extends StatelessWidget {
  const DSlider({super.key, required this.label, required this.value, required this.min, required this.max, required this.step, required this.display, required this.onChanged});

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = ((max - min) / step).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 82),
            child: Text(context.t(label), style: const TextStyle(fontSize: 13, color: DColors.ink2)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: DColors.line2,
                inactiveTrackColor: DColors.line2,
                thumbColor: DColors.ink,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 0, pressedElevation: 0),
                trackShape: const RoundedRectSliderTrackShape(),
                showValueIndicator: ShowValueIndicator.never,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Semantics(
                label: context.t(label),
                child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, onChanged: (v) => onChanged(double.parse(v.toStringAsFixed(2)))),
              ),
            ),
          ),
          const SizedBox(width: 11),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 62),
            child: Text(
              context.t(display),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.otp` — six single-digit boxes with auto-advance and backspace.
class DOtp extends StatefulWidget {
  const DOtp({super.key, this.initial = '', this.length = 6, this.onChanged});

  final String initial;
  final int length;
  final ValueChanged<String>? onChanged;

  @override
  State<DOtp> createState() => _DOtpState();
}

class _DOtpState extends State<DOtp> {
  late final List<TextEditingController> _c = List.generate(widget.length, (i) => TextEditingController(text: i < widget.initial.length ? widget.initial[i] : ''));
  late final List<FocusNode> _f = List.generate(widget.length, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    for (final f in _f) {
      f.dispose();
    }
    super.dispose();
  }

  void _changed(int i, String v) {
    if (v.length == 2) {
      // Typed over a filled box: keep the new digit and move on.
      _c[i].text = v.substring(1);
      if (i < widget.length - 1) _f[i + 1].requestFocus();
    } else if (v.length > 2) {
      // Pasted a whole code: spread it across the boxes.
      final digits = v.replaceAll(RegExp(r'\D'), '');
      for (var j = 0; j < widget.length; j++) {
        _c[j].text = j < digits.length ? digits[j] : '';
      }
      _f[(digits.length).clamp(0, widget.length - 1)].requestFocus();
    } else if (v.isNotEmpty && i < widget.length - 1) {
      _f[i + 1].requestFocus();
    }
    widget.onChanged?.call(_c.map((c) => c.text).join());
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DRadius.input),
      borderSide: BorderSide(color: c),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Directionality(
        // Codes read left to right in both languages (`body.ar .otp input{direction:ltr}`).
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, c) {
            // 48×56 boxes as designed; narrower on small phones so six still fit.
            final boxW = ((c.maxWidth - 9 * (widget.length - 1)) / widget.length).clamp(30.0, 48.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.length; i++) ...[
                  if (i > 0) const SizedBox(width: 9),
                  SizedBox(
                    width: boxW,
                    height: 56,
                    child: Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: (node, e) {
                        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.backspace && _c[i].text.isEmpty && i > 0) {
                          _f[i - 1].requestFocus();
                          _c[i - 1].clear();
                          widget.onChanged?.call(_c.map((c) => c.text).join());
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _c[i],
                        focusNode: _f[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(widget.length)],
                        cursorColor: DColors.ink,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: DColors.ink),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: DColors.white,
                          contentPadding: EdgeInsets.zero,
                          border: border(DColors.line),
                          enabledBorder: border(DColors.line),
                          focusedBorder: border(DColors.ink),
                          counterText: '',
                        ),
                        onChanged: (v) => _changed(i, v),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
