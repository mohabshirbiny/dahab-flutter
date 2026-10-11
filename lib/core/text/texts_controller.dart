import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../services/api/content_api.dart';
import '../i18n/i18n.dart';
import 'app_controls.dart';
import 'keys/all_keys.dart';
import 'keys/patterns.dart';
import 'text_bundle.dart';
import 'text_key.dart';
import 'texts_store.dart';

/// Published texts for the customer app (backend spec 019, Q3).
///
/// Holds the last published bundle in memory and on the device. It is read from the device
/// at start, then asked for again on start, when the app returns to the foreground and every
/// 15 minutes while open; the server answers 304 when nothing moved. Any failure keeps what
/// is held, so a screen never goes blank (FR-005): a key the bundle does not carry, a missing
/// language or a placeholder that cannot be filled all show the code's own text.
class TextsController extends ChangeNotifier with WidgetsBindingObserver {
  TextsController({ContentApi? api, TextsStore? store, this.refreshEvery = const Duration(minutes: 15)})
    : _api = api,
      _store = store ?? TextsStore();

  final ContentApi? _api;
  final TextsStore _store;
  final Duration refreshEvery;

  TextBundle _bundle = TextBundle.empty;
  bool _hasPatternOverrides = false;
  AppControls _controls = AppControls.none;
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _refreshing = false;

  TextBundle get bundle => _bundle;

  /// What is stopped or paused, and what customers can see; nothing is off until the server says so.
  AppControls get controls => _controls;

  /// Reads the saved copy; call before the first frame so a returning customer never sees a flash of defaults.
  Future<void> loadSaved() async {
    final saved = await _store.read();
    if (saved != null && !_disposed) {
      _setBundle(saved);
      notifyListeners();
    }
  }

  /// Asks the server now and then keeps asking (start, resume, every [refreshEvery]).
  void start() {
    if (_started || _api == null) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(refreshEvery, (_) => refresh());
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// One refresh. Never throws and never clears what is held.
  Future<void> refresh() async {
    final api = _api;
    if (api == null || _refreshing || _disposed) return;
    _refreshing = true;
    try {
      // The switches ride along: a stop or a pause shows up as soon as the app asks again.
      try {
        final c = await api.controls();
        if (c != null && !_disposed) {
          _controls = c;
          notifyListeners();
        }
      } catch (_) {
        // Keep what is held.
      }
      final next = await api.appTexts(tag: _bundle.tag);
      if (next == null || _disposed) return;
      _setBundle(next);
      await _store.write(next);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Offline, 404 on an older backend, a bad answer: keep the saved copy (Q3).
    } finally {
      _refreshing = false;
    }
  }

  /// The published Help entries in the order staff set, in the current language. An entry
  /// missing a half, or with a `{name}` that cannot be filled, is left out; the app has no
  /// Help of its own to fall back to.
  List<FaqItem> faq(LangController lang) {
    String? pick(Object? part) {
      if (part is! Map) return null;
      final en = part['en'];
      final ar = part['ar'];
      final raw = lang.isArabic && ar is String && ar.trim().isNotEmpty ? ar : en;
      return raw is String && raw.trim().isNotEmpty ? TextKey.fill(raw, _bundle.settings) : null;
    }

    final out = <FaqItem>[];
    for (final e in _bundle.faq) {
      final q = pick(e['question']);
      final a = pick(e['answer']);
      if (q != null && a != null) out.add(FaqItem(q, a));
    }
    return out;
  }

  /// Holds [texts] as the published bundle, with no server involved (tests).
  @visibleForTesting
  void seedForTest(Map<String, ({String en, String ar})> texts, {Map<String, Object?> settings = const {}}) {
    _setBundle(TextBundle(version: 1, texts: texts, settings: settings));
    notifyListeners();
  }

  /// Holds [controls] with no server involved (tests).
  @visibleForTesting
  void seedControlsForTest(AppControls controls) {
    _controls = controls;
    notifyListeners();
  }

  void _setBundle(TextBundle next) {
    _bundle = next;
    _hasPatternOverrides = next.texts.keys.any((k) => k.startsWith('pattern.'));
  }

  /// The published value of [key] in this language, filled; null when there is none, it is
  /// empty in this language, or a `{name}` in it cannot be filled.
  String? _published(TextKey key, LangController lang, Map<String, Object?> params) {
    final published = _bundle.texts[key.key];
    if (published == null) return null;
    final raw = lang.isArabic ? published.ar : published.en;
    if (raw.trim().isEmpty) return null;
    return TextKey.fill(raw, {..._bundle.settings, ...params});
  }

  /// The text to show for [key] in the current language.
  ///
  /// The published value when the bundle has one for [key], it is not empty in this language,
  /// and every `{name}` in it can be filled from [params] or the bundle's setting values;
  /// otherwise the code's own English, translated and filled the way the screen always did.
  String resolve(TextKey key, LangController lang, [Map<String, Object?> params = const {}]) {
    return _published(key, lang, params) ?? fallback(key, lang, params);
  }

  static final Map<String, TextKey> _englishKeys = {
    for (final k in allTextKeys) k.en.replaceAll(RegExp(r'\s+'), ' ').trim(): k,
  };

  static final List<(RegExp, TextKey, List<String>)> _patternKeys = [
    for (final p in PatternKeys.table) (RegExp(p.expression), p.key, p.names),
  ];

  /// What staff published for a sentence the screens hand to `context.t`, or null (the screen
  /// then translates it the way it always did).
  ///
  /// [en] is the English the screen built. Fixed sentences are found by their English; sentences
  /// with a number, a name or a date in them by the same expressions the Arabic translation
  /// uses, each group filling the placeholder of that name (backend spec 019, R14).
  String? published(String en, LangController lang) {
    if (_bundle.texts.isEmpty) return null;
    final text = en.replaceAll(RegExp(r'\s+'), ' ').trim();
    final key = _englishKeys[text];
    if (key != null) return _published(key, lang, const {});
    if (!_hasPatternOverrides) return null;
    for (final (re, patternKey, names) in _patternKeys) {
      final m = re.firstMatch(text);
      if (m == null) continue;
      return _published(patternKey, lang, {
        for (var i = 0; i < names.length; i++) names[i]: m.group(i + 1),
      });
    }
    return null;
  }

  /// The code text: English filled first, then translated, so the existing patterns in the
  /// dictionary (`3 h 20 min left`) still produce the same Arabic as before.
  static String fallback(TextKey key, LangController lang, [Map<String, Object?> params = const {}]) {
    String fill(String text) => text.replaceAllMapped(TextKey.placeholder, (m) {
      final v = params[m.group(1)!];
      return v == null ? m.group(0)! : v.toString();
    });
    final en = fill(key.en);
    // A key the dictionary has no Arabic for (a sentence written for this text system) carries its own.
    if (lang.isArabic && key.ar != null && lang.arabicFor(en) == null) return fill(key.ar!);
    return lang.t(en);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

extension TextsContext on BuildContext {
  /// The text for [key] in the current language, subscribing to language and bundle changes.
  /// Without a [TextsController] above (a bare widget test) it is the code's text.
  String k(TextKey key, [Map<String, Object?> params = const {}]) {
    final lang = watch<LangController>();
    final texts = Provider.of<TextsController?>(this);
    return texts?.resolve(key, lang, params) ?? TextsController.fallback(key, lang, params);
  }

  /// [k] without subscribing — for callbacks, dialogs and toasts.
  String kr(TextKey key, [Map<String, Object?> params = const {}]) {
    final lang = read<LangController>();
    final texts = Provider.of<TextsController?>(this, listen: false);
    return texts?.resolve(key, lang, params) ?? TextsController.fallback(key, lang, params);
  }
}
