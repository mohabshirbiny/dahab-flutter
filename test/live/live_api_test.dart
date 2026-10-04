/// Live check of the app's auth code against a running backend + database.
///
/// Skipped unless LIVE_API is set:
///   LIVE_API=http://127.0.0.1:8000/api/v1 flutter test test/live/live_api_test.dart
///
/// Needs the local backend (`php artisan serve`), seeded staff
/// (`php artisan db:seed`) and APP_ENV=local, where every OTP is 123456.
/// It creates one new customer and approves it through the Dashboard API.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dahab_app/services/api/api_client.dart';
import 'package:dahab_app/services/api/token_store.dart';
import 'package:dahab_app/services/auth/auth_api.dart';
import 'package:dahab_app/services/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final _base = Platform.environment['LIVE_API'];

/// A tiny valid PNG (2×2) for the ID photos.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP4/58BCBgYGBgYGBgYGAAAeAAE/wVXeGYAAAAASUVORK5CYII=');

Future<AuthController> _app() async {
  SharedPreferences.setMockInitialValues({});
  final tokens = await TokenStore.open();
  final client = ApiClient(tokens, baseUrl: _base);
  return AuthController(api: AuthApi(client), tokens: tokens, client: client);
}

Future<void> _approve(String customerId) async {
  final h = {'Accept': 'application/json', 'Content-Type': 'application/json', 'X-Device-Id': 'live-test-staff', 'X-Device-Platform': 'web'};
  final login = await http.post(Uri.parse('$_base/dashboard/auth/login'), headers: h, body: jsonEncode({'email': 'verification@dahab.test', 'password': 'seeded-password-1'}));
  expect(login.statusCode, 200, reason: login.body);
  final token = (jsonDecode(login.body)['data']['session']['access_token']) as String;
  final auth = {...h, 'Authorization': 'Bearer $token'};
  final detail = await http.get(Uri.parse('$_base/dashboard/customers/$customerId'), headers: auth);
  expect(detail.statusCode, 200, reason: detail.body);
  final docId = jsonDecode(detail.body)['data']['latest_document']['document_id'];
  final review = await http.post(Uri.parse('$_base/dashboard/identity-documents/$docId/review'), headers: auth, body: jsonEncode({'action': 'verify'}));
  expect(review.statusCode, 200, reason: review.body);
}

void main() {
  test(
    'register → pending → approved → new-device OTP sign-in → me → sign out',
    () async {
      final rng = Random();
      final phone = '+2010${List.generate(8, (_) => rng.nextInt(10)).join()}';
      const password = 'Dahab-Live-Check-2026!';
      final email = 'live.${DateTime.now().millisecondsSinceEpoch}@example.com';

      // Registration, exactly as the three sign-up screens call it.
      final signUp = await _app();
      await signUp.registerStart(name: 'Live Check', phone: phone, password: password, lang: 'en');
      await signUp.registerPhoneAndEmail(phoneOtp: '123456', email: email, governorate: 'cairo');
      await signUp.registerVerifyEmail('123456');
      final created = await signUp.registerDocumentsAndSubmit(
        documentType: 'egyptian_id',
        front: UploadFile(field: 'front', filename: 'front.png', bytes: _png, contentType: 'image/png'),
        back: UploadFile(field: 'back', filename: 'back.png', bytes: _png, contentType: 'image/png'),
      );
      expect(created.status, 'pending_verification');
      expect(created.phone, phone);

      // Backend spec 002: a pending account can sign in (trading waits for approval).
      final early = await _app();
      expect(await early.login(phone: phone, password: password), LoginOutcome.needsOtp);

      await _approve(created.id);

      // A fresh browser = a new device: password, then the SMS code.
      final app = await _app();
      expect(await app.login(phone: phone, password: password), LoginOutcome.needsOtp);
      await expectLater(app.verifyLoginOtp('000000'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'otp_invalid')));
      await app.verifyLoginOtp('123456');
      expect(app.isSignedIn, isTrue);
      expect(app.customer!.status, 'active');
      expect(app.customer!.email, email);

      // Session survives a reload (tokens → /me).
      await app.restore();
      expect(app.customer!.phone, phone);

      // Same device again → straight in, no code.
      expect(await app.login(phone: phone, password: password), LoginOutcome.signedIn);

      await app.logout();
      expect(app.isSignedIn, isFalse);
      // ignore: avoid_print
      print('live check passed for $phone');
    },
    skip: _base == null ? 'set LIVE_API to run against a live backend' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
