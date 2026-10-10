import 'dart:math' as math;

/// One visible sentence, label or button of the customer app (backend spec 019, Q1).
///
/// The key is readable and stable — `<screen>.<part>.<purpose>`, lower case, dots — and is
/// never renamed once released. [en] is the code's own English: it is the default and the
/// fallback, and the Arabic default is whatever [LangController.arabicFor] already has for
/// it, so no Arabic is typed twice. A published override replaces both languages; a missing
/// key, language or placeholder never breaks a screen (FR-005).
///
/// [placeholders] lists the `{names}` the sentence may contain. The caller fills the
/// screen's own names; the setting names (`{commission_gold_pct}`, …) come from the bundle.
class TextKey {
  const TextKey(
    this.key,
    this.en, {
    this.ar,
    this.placeholders = const [],
    this.maxLength,
    this.area = '',
    this.where = '',
  });

  final String key;
  final String en;

  /// The Arabic default when it cannot be looked up from [en] — a sentence with `{names}`,
  /// which the dictionary only knows by pattern. Copied from that pattern, never retyped.
  /// Null = whatever `LangController.arabicFor(en)` has.
  final String? ar;
  final List<String> placeholders;

  /// Longest value staff may publish; null = the registry default, max(2 × default, 40).
  final int? maxLength;

  /// Registry grouping (Home, Orders, Selling, …) and a plain "where it appears".
  final String area;
  final String where;

  int get limit => maxLength ?? math.max(2 * en.length, 40);

  /// `{name}` — snake_case, as the backend validates it.
  static final RegExp placeholder = RegExp(r'\{([a-z][a-z0-9_]*)\}');

  /// The names this text uses, in order of first appearance.
  static List<String> namesIn(String text) {
    final seen = <String>[];
    for (final m in placeholder.allMatches(text)) {
      final n = m.group(1)!;
      if (!seen.contains(n)) seen.add(n);
    }
    return seen;
  }

  /// [text] with every `{name}` replaced by [values]; null when one cannot be filled.
  static String? fill(String text, Map<String, Object?> values) {
    var ok = true;
    final out = text.replaceAllMapped(placeholder, (m) {
      final v = values[m.group(1)!];
      final s = v?.toString() ?? '';
      if (s.isEmpty) ok = false;
      return s;
    });
    return ok ? out : null;
  }

  @override
  String toString() => 'TextKey($key)';
}
