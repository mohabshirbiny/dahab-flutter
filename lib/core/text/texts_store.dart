import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'text_bundle.dart';

/// The last published bundle, kept on the device (Q3): offline, or while the first load is
/// still running, the app shows these values; with nothing saved it shows the code's text.
class TextsStore {
  TextsStore([SharedPreferences? prefs]) : _prefs = prefs;

  static const _key = 'dahab.app_texts.bundle';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  Future<TextBundle?> read() async {
    try {
      final raw = (await _p).getString(_key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      return json is Map<String, dynamic> ? TextBundle.fromJson(json) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(TextBundle bundle) async {
    try {
      await (await _p).setString(_key, jsonEncode(bundle.toJson()));
    } catch (_) {
      // A failed save only means the next start loads it again.
    }
  }
}
