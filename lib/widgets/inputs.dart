import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/data/countries.dart';
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

/// The calling-code button of a phone field: flag + code, styled like [DSelect].
/// A tap opens every country with a search box ([countries]); [onChanged] gets the
/// chosen country, whose `dial` goes in front of the number.
class DCountryCode extends StatelessWidget {
  const DCountryCode({super.key, required this.country, required this.onChanged});

  final Country country;
  final ValueChanged<Country> onChanged;

  Future<void> _open(BuildContext context) async {
    final picked = await showDialog<Country>(
      context: context,
      barrierColor: DColors.modalBarrier,
      builder: (_) => _CountryDialog(current: country),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${context.t('Country code')}: ${country.name(context.isArabic)} ${country.dial}',
      child: Tappable(
        onTap: () => _open(context),
        child: InputDecorator(
          decoration: _decoration(context, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${country.flag} ${country.dial}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 14, height: 1.6, color: DColors.ink, fontFamilyFallback: ['Noto Color Emoji']),
                ),
              ),
              const RotatedBox(quarterTurns: 1, child: DIcon('chevron-right', size: 14, color: DColors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountryDialog extends StatefulWidget {
  const _CountryDialog({required this.current});

  final Country current;

  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  String _query = '';

  List<Country> _matches(bool arabic) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      final popular = [for (final iso in popularCountryIsos) countries.firstWhere((c) => c.iso == iso)];
      final rest = countries.where((c) => !popularCountryIsos.contains(c.iso)).toList()..sort((a, b) => a.name(arabic).compareTo(b.name(arabic)));
      return [...popular, ...rest];
    }
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return countries
        .where((c) => c.en.toLowerCase().contains(q) || c.ar.contains(q) || c.iso.toLowerCase() == q || (digits.isNotEmpty && c.dial.substring(1).startsWith(digits)))
        .toList()
      ..sort((a, b) => a.name(arabic).compareTo(b.name(arabic)));
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    final list = _matches(arabic);
    return Dialog(
      backgroundColor: DColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DRadius.modal)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('Country code'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                cursorColor: DColors.ink,
                style: const TextStyle(fontSize: 14, height: 1.6, color: DColors.ink),
                decoration: _decoration(context, hint: 'Search a country or code'),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(context.t('No country matches.'), style: DText.muted),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final c = list[i];
                          final selected = c.iso == widget.current.iso;
                          return Tappable(
                            onTap: () => Navigator.of(context).pop(c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              decoration: BoxDecoration(color: selected ? DColors.paper : null, borderRadius: BorderRadius.circular(DRadius.input)),
                              child: Row(
                                children: [
                                  Text(c.flag, style: const TextStyle(fontSize: 18, fontFamilyFallback: ['Noto Color Emoji'])),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(c.name(arabic), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: DColors.ink)),
                                  ),
                                  Text(c.dial, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, color: DColors.ink2)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
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
  const DSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.display,
    required this.onChanged,
    this.typeMax,
    this.typeDecimals = 0,
    this.unit,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String display;
  final ValueChanged<double> onChanged;

  /// When set, tapping the value opens a box to type an exact number (up to [typeMax], with
  /// [typeDecimals] decimals), beyond the slider's own steps and range.
  final double? typeMax;
  final int typeDecimals;

  /// Shown after the typed number, e.g. `g`.
  final String? unit;

  Future<void> _type(BuildContext context) async {
    final typed = await showDialog<double>(
      context: context,
      barrierColor: DColors.modalBarrier,
      builder: (_) => _TypeNumberDialog(label: label, value: value, max: typeMax!, decimals: typeDecimals, unit: unit),
    );
    if (typed != null) onChanged(typed);
  }

  @override
  Widget build(BuildContext context) {
    final divisions = ((max - min) / step).round();
    final shown = Text(
      context.t(display),
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        decoration: typeMax == null ? null : TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
        decorationColor: DColors.ink3,
      ),
    );
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
            child: typeMax == null
                ? shown
                : Semantics(
                    button: true,
                    label: context.t('Type the number'),
                    child: Tappable(onTap: () => _type(context), child: shown),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The slider's "type the number" box: one number field, Cancel and Use.
class _TypeNumberDialog extends StatefulWidget {
  const _TypeNumberDialog({required this.label, required this.value, required this.max, required this.decimals, this.unit});

  final String label;
  final double value;
  final double max;
  final int decimals;
  final String? unit;

  @override
  State<_TypeNumberDialog> createState() => _TypeNumberDialogState();
}

class _TypeNumberDialogState extends State<_TypeNumberDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.value.toStringAsFixed(widget.decimals));
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _use() {
    final v = double.tryParse(_c.text.replaceAll(',', '').trim());
    if (v == null || v <= 0 || v > widget.max) {
      setState(() => _error = 'Enter a number above 0 and up to ${widget.max.round()}.');
      return;
    }
    Navigator.of(context).pop(double.parse(v.toStringAsFixed(widget.decimals)));
  }

  @override
  Widget build(BuildContext context) {
    final pattern = widget.decimals == 0 ? r'^\d*$' : '^\\d*\\.?\\d{0,${widget.decimals}}\$';
    return Dialog(
      backgroundColor: DColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DRadius.modal)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t(widget.label), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DInput(
                      controller: _c,
                      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals > 0),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(pattern))],
                      onSubmitted: (_) => _use(),
                    ),
                  ),
                  if (widget.unit != null) ...[const SizedBox(width: 10), Text(context.t(widget.unit!), style: const TextStyle(fontSize: 13, color: DColors.ink2))],
                ],
              ),
              DError(_error ?? '', visible: _error != null),
              const SizedBox(height: 16),
              DActsRow(
                gap: 9,
                children: [
                  DButton.ghost('Cancel', onTap: () => Navigator.of(context).pop()),
                  DButton('Use', onTap: _use),
                ],
              ),
            ],
          ),
        ),
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
