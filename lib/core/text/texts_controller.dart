import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../services/api/content_api.dart';
import '../i18n/i18n.dart';
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
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;
  bool _refreshing = false;

  TextBundle get bundle => _bundle;

  /// Reads the saved copy; call before the first frame so a returning customer never sees a flash of defaults.
  Future<void> loadSaved() async {
    final saved = await _store.read();
    if (saved != null && !_disposed) {
      _bundle = saved;
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
      final next = await api.appTexts(tag: _bundle.tag);
      if (next == null || _disposed) return;
      _bundle = next;
      await _store.write(next);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Offline, 404 on an older backend, a bad answer: keep the saved copy (Q3).
    } finally {
      _refreshing = false;
    }
  }

  /// The text to show for [key] in the current language.
  ///
  /// The published value when the bundle has one for [key], it is not empty in this language,
  /// and every `{name}` in it can be filled from [params] or the bundle's setting values;
  /// otherwise the code's own English, translated and filled the way the screen always did.
  String resolve(TextKey key, LangController lang, [Map<String, Object?> params = const {}]) {
    final published = _bundle.texts[key.key];
    if (published != null) {
      final raw = lang.isArabic ? published.ar : published.en;
      if (raw.trim().isNotEmpty) {
        final filled = TextKey.fill(raw, {..._bundle.settings, ...params});
        if (filled != null) return filled;
      }
    }
    return fallback(key, lang, params);
  }

  /// The code text: English filled first, then translated, so the existing patterns in the
  /// dictionary (`3 h 20 min left`) still produce the same Arabic as before.
  static String fallback(TextKey key, LangController lang, [Map<String, Object?> params = const {}]) {
    final en = key.en.replaceAllMapped(TextKey.placeholder, (m) {
      final v = params[m.group(1)!];
      return v == null ? m.group(0)! : v.toString();
    });
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
