import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../core/config/app_config.dart';
import '../../models/customer.dart';
import 'token_store.dart';

/// An error answer from the API, in the backend's envelope
/// `{ "message", "code", "errors"? }` (see bootstrap/app.php).
class ApiException implements Exception {
  const ApiException({required this.status, required this.code, required this.message, this.fieldErrors = const {}, this.extra = const {}});

  /// HTTP status; 0 when the server could not be reached.
  final int status;

  /// Stable machine-readable code (`invalid_credentials`, `otp_invalid`, …).
  final String code;
  final String message;

  /// Per-field messages on `validation_failed`.
  final Map<String, List<String>> fieldErrors;

  /// Any other top-level keys (e.g. `resend_available_at`).
  final Map<String, dynamic> extra;

  String? fieldError(String field) {
    final list = fieldErrors[field];
    return list == null || list.isEmpty ? null : list.first;
  }

  bool get isNetwork => status == 0;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// A file part for multipart uploads.
class UploadFile {
  const UploadFile({required this.field, required this.filename, required this.bytes, required this.contentType});

  final String field;
  final String filename;
  final List<int> bytes;
  final String contentType;
}

/// Thin JSON client for `/api/v1`. Every request carries the device headers
/// the backend uses for device trust. Authenticated calls send the access
/// token and, when it has expired, rotate the refresh token once and retry.
class ApiClient {
  ApiClient(this._tokens, {http.Client? httpClient, String? baseUrl}) : _http = httpClient ?? http.Client(), _base = baseUrl ?? AppConfig.apiBaseUrl;

  final TokenStore _tokens;
  final http.Client _http;
  final String _base;

  /// Called when the refresh token is rejected — the session is over.
  void Function()? onSessionExpired;

  Future<SessionTokens>? _refreshing;

  Map<String, String> get _deviceHeaders => {'Accept': 'application/json', 'X-Device-Id': _tokens.deviceId, 'X-Device-Platform': AppConfig.devicePlatform};

  Future<Map<String, dynamic>?> get(String path, {bool auth = false}) => _send('GET', path, auth: auth);

  /// `idempotencyKey` sends the backend's `Idempotency-Key` header (money and
  /// notice actions, backend spec 007/009). Reuse the same key when retrying the
  /// same submission, so the backend replays the first answer instead of acting twice.
  Future<Map<String, dynamic>?> post(String path, {Map<String, dynamic>? body, bool auth = false, String? idempotencyKey}) =>
      _send('POST', path, body: body, auth: auth, idempotencyKey: idempotencyKey);

  /// `DELETE` (removing a saved piece, backend spec 017).
  Future<Map<String, dynamic>?> delete(String path, {bool auth = false}) => _send('DELETE', path, auth: auth);

  /// `PATCH` with a JSON body (editing a listing, backend spec 010).
  Future<Map<String, dynamic>?> patch(String path, {Map<String, dynamic>? body, bool auth = false, String? idempotencyKey}) =>
      _send('PATCH', path, body: body, auth: auth, idempotencyKey: idempotencyKey);

  /// The bytes of a file the API streams (a listing photo, backend spec 010).
  /// [path] is either relative to the API base (`/market/…`) or the full
  /// `/api/v1/…` path the API returns in a media `url`.
  Future<({List<int> bytes, String contentType})> getBytes(String path, {bool auth = false}) async {
    if (auth) await _ensureFreshAccess();
    final res = await _guard(
      () => _http
          .get(
            _mediaUri(path),
            headers: {
              'X-Device-Id': _tokens.deviceId,
              'X-Device-Platform': AppConfig.devicePlatform,
              if (auth && _tokens.accessToken != null) 'Authorization': 'Bearer ${_tokens.accessToken}',
            },
          )
          .timeout(AppConfig.requestTimeout),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // A JSON refusal keeps its code (backend spec 016: `document_not_ready`).
      String? code;
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body is Map && body['code'] is String) code = body['code'] as String;
      } catch (_) {}
      throw ApiException(status: res.statusCode, code: code ?? (res.statusCode == 404 ? 'not_found' : 'server_error'), message: 'The file could not be loaded.');
    }
    return (bytes: res.bodyBytes, contentType: res.headers['content-type'] ?? 'application/octet-stream');
  }

  /// The absolute address of a media `url` from the API. Public market media
  /// needs no token, so this can be opened in a browser tab as it is.
  Uri mediaUri(String path) => _mediaUri(path);

  Uri _mediaUri(String path) {
    final base = Uri.parse(_base);
    // The API returns `/api/v1/…`; the base already ends with that prefix.
    final full = path.startsWith(base.path) ? path : '${base.path}$path';
    return base.replace(path: full);
  }

  /// `auth` sends the access token (customer uploads, e.g. a top-up receipt).
  Future<Map<String, dynamic>?> postMultipart(String path, {required Map<String, String> fields, required List<UploadFile> files, bool auth = false}) async {
    if (auth) await _ensureFreshAccess();
    final req = http.MultipartRequest('POST', Uri.parse('$_base$path'))
      ..headers.addAll(_deviceHeaders)
      ..headers.addAll({if (auth && _tokens.accessToken != null) 'Authorization': 'Bearer ${_tokens.accessToken}'})
      ..fields.addAll(fields);
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.filename, contentType: _mediaType(f.contentType)));
    }
    final streamed = await _guard(() => _http.send(req).timeout(AppConfig.requestTimeout));
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<Map<String, dynamic>?> _send(String method, String path, {Map<String, dynamic>? body, required bool auth, String? idempotencyKey, bool retried = false}) async {
    if (auth) await _ensureFreshAccess();
    final headers = {
      ..._deviceHeaders,
      if (body != null) 'Content-Type': 'application/json',
      if (auth && _tokens.accessToken != null) 'Authorization': 'Bearer ${_tokens.accessToken}',
      'Idempotency-Key': ?idempotencyKey,
    };
    final uri = Uri.parse('$_base$path');
    final res = await _guard(() {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      return _http.send(req).then(http.Response.fromStream).timeout(AppConfig.requestTimeout);
    });

    if (auth && res.statusCode == 401 && !retried && _tokens.refreshToken != null) {
      await _refresh();
      return _send(method, path, body: body, auth: auth, idempotencyKey: idempotencyKey, retried: true);
    }
    return _decode(res);
  }

  /// Rotate ahead of time when the access token is about to lapse.
  Future<void> _ensureFreshAccess() async {
    final exp = _tokens.accessExpiresAt;
    if (_tokens.refreshToken == null) return;
    if (_tokens.accessToken == null || exp == null || exp.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      await _refresh();
    }
  }

  /// `POST /customer/auth/refresh` with the refresh token as Bearer. Rotates
  /// on every use, so concurrent callers share one in-flight refresh.
  Future<SessionTokens> _refresh() {
    return _refreshing ??= () async {
      try {
        final refresh = _tokens.refreshToken;
        if (refresh == null) throw const ApiException(status: 401, code: 'unauthenticated', message: 'Signed out.');
        final res = await _guard(
          () => _http.post(Uri.parse('$_base/customer/auth/refresh'), headers: {..._deviceHeaders, 'Authorization': 'Bearer $refresh'}).timeout(AppConfig.requestTimeout),
        );
        try {
          final json = _decode(res)!;
          final session = SessionTokens.fromJson(json['data'] as Map<String, dynamic>);
          await _tokens.save(session);
          return session;
        } on ApiException catch (e) {
          if (!e.isNetwork) {
            await _tokens.clear();
            onSessionExpired?.call();
          }
          rethrow;
        }
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(status: 0, code: 'network_error', message: 'Could not reach the server.');
    }
  }

  Map<String, dynamic>? _decode(http.Response res) {
    Map<String, dynamic>? json;
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        json = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;

    final errors = <String, List<String>>{};
    final rawErrors = json?['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((k, v) {
        if (v is List) errors['$k'] = v.map((e) => '$e').toList();
      });
    }
    throw ApiException(
      status: res.statusCode,
      code: (json?['code'] as String?) ?? 'server_error',
      message: (json?['message'] as String?) ?? 'Something went wrong',
      fieldErrors: errors,
      extra: {...?json}..removeWhere((k, _) => k == 'code' || k == 'message' || k == 'errors'),
    );
  }

  static MediaType? _mediaType(String contentType) {
    final parts = contentType.split('/');
    return parts.length == 2 ? MediaType(parts[0], parts[1]) : null;
  }
}
