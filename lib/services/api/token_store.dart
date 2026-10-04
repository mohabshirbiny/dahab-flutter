import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/customer.dart';

/// Persists the device id and the customer's token pair (localStorage on web).
///
/// The device id identifies this browser to the backend (`X-Device-Id`); a
/// sign-in from a new id needs the SMS code once, after which the device is
/// trusted. It is generated once and kept for good.
class TokenStore {
  TokenStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _kDevice = 'dahab.device_id';
  static const _kAccess = 'dahab.access_token';
  static const _kAccessExp = 'dahab.access_token_expires_at';
  static const _kRefresh = 'dahab.refresh_token';

  static Future<TokenStore> open() async => TokenStore._(await SharedPreferences.getInstance());

  String get deviceId {
    final existing = _prefs.getString(_kDevice);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final id = 'web-${List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    _prefs.setString(_kDevice, id);
    return id;
  }

  String? get accessToken => _prefs.getString(_kAccess);
  String? get refreshToken => _prefs.getString(_kRefresh);
  bool get hasSession => refreshToken != null;

  DateTime? get accessExpiresAt {
    final v = _prefs.getString(_kAccessExp);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> save(SessionTokens s) async {
    await _prefs.setString(_kAccess, s.accessToken);
    await _prefs.setString(_kAccessExp, s.accessTokenExpiresAt.toIso8601String());
    await _prefs.setString(_kRefresh, s.refreshToken);
  }

  Future<void> clear() async {
    await _prefs.remove(_kAccess);
    await _prefs.remove(_kAccessExp);
    await _prefs.remove(_kRefresh);
  }
}
