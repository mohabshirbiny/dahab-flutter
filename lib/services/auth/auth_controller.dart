import 'package:flutter/foundation.dart';

import '../../models/customer.dart';
import '../api/api_client.dart';
import '../api/token_store.dart';
import 'auth_api.dart';

/// Where a sign-in attempt ended up.
enum LoginOutcome { signedIn, needsOtp }

/// The customer's authentication state: session restore, sign-in (with the
/// new-device SMS step), sign-out, and the in-progress registration.
///
/// Screens call these methods and show [ApiException.code] as a message;
/// nothing here touches widgets.
class AuthController extends ChangeNotifier {
  AuthController({required AuthApi api, required TokenStore tokens, required ApiClient client}) : _api = api, _tokens = tokens {
    client.onSessionExpired = _expired;
  }

  final AuthApi _api;
  final TokenStore _tokens;

  CustomerProfile? _customer;
  CustomerProfile? get customer => _customer;
  bool get isSignedIn => _customer != null;

  /// Set when a session ended on its own (refresh rejected) so the app can
  /// send the user back to the start.
  bool _sessionExpired = false;
  bool takeSessionExpired() {
    final v = _sessionExpired;
    _sessionExpired = false;
    return v;
  }

  // ---- startup ----

  /// Reload the signed-in customer from stored tokens, if any.
  Future<void> restore() async {
    if (!_tokens.hasSession) return;
    try {
      _customer = await _api.me();
    } on ApiException catch (e) {
      // Offline: keep the tokens and try again next launch.
      if (!e.isNetwork) await _tokens.clear();
      _customer = null;
    }
    notifyListeners();
  }

  /// Reload the signed-in customer after their phone or email changed (backend spec 017).
  /// A failure keeps the current record.
  Future<void> refreshMe() async {
    if (!_tokens.hasSession) return;
    try {
      _customer = await _api.me();
      notifyListeners();
    } on ApiException {
      // Keep what we have.
    }
  }

  /// The account was closed (backend spec 017): the backend already ended every
  /// session, so this only forgets it here.
  Future<void> endLocally() async {
    await _tokens.clear();
    _customer = null;
    notifyListeners();
  }

  // ---- sign-in ----

  OtpChallenge? _challenge;
  String? _challengePhone;
  String? _challengePassword;
  OtpChallenge? get pendingChallenge => _challenge;
  String? get pendingPhone => _challengePhone;

  Future<LoginOutcome> login({required String phone, required String password}) async {
    final result = await _api.login(phone: phone, password: password);
    switch (result) {
      case LoginSignedIn(:final customer, :final session):
        await _startSession(customer, session);
        return LoginOutcome.signedIn;
      case LoginNeedsOtp(:final challenge):
        _challenge = challenge;
        _challengePhone = phone;
        _challengePassword = password;
        notifyListeners();
        return LoginOutcome.needsOtp;
    }
  }

  Future<void> verifyLoginOtp(String code) async {
    final c = _challenge;
    if (c == null) throw const ApiException(status: 401, code: 'otp_invalid', message: 'Sign in again.');
    final result = await _api.verifyLoginOtp(challengeId: c.challengeId, code: code);
    await _startSession(result.customer, result.session);
  }

  /// A fresh code on the same challenge; if the challenge has gone (voided,
  /// expired), sign in again with the credentials still in memory.
  Future<void> resendLoginOtp() async {
    final c = _challenge;
    if (c == null) throw const ApiException(status: 401, code: 'otp_invalid', message: 'Sign in again.');
    try {
      _challenge = await _api.resendLoginOtp(c.challengeId);
    } on ApiException catch (e) {
      if (e.code != 'otp_invalid' || _challengePhone == null || _challengePassword == null) rethrow;
      await login(phone: _challengePhone!, password: _challengePassword!);
    }
    notifyListeners();
  }

  Future<void> _startSession(CustomerProfile customer, SessionTokens session) async {
    await _tokens.save(session);
    _customer = customer;
    _challenge = null;
    _challengePhone = null;
    _challengePassword = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (_tokens.hasSession) await _api.logout();
    } on ApiException {
      // Revocation failed (offline / already expired) — sign out locally anyway.
    }
    await _tokens.clear();
    _customer = null;
    notifyListeners();
  }

  /// Signs out on every device, this one included. Unlike [logout], a failed call
  /// is reported: the other devices would still be signed in.
  Future<void> logoutAll() async {
    await _api.logoutAll();
    await _tokens.clear();
    _customer = null;
    notifyListeners();
  }

  void _expired() {
    if (_customer == null) return;
    _customer = null;
    _sessionExpired = true;
    notifyListeners();
  }

  // ---- registration ----

  RegistrationDraft? _draft;
  RegistrationDraft? get draft => _draft;

  /// Step 1: name, phone, password → phone code sent.
  Future<void> registerStart({required String name, required String phone, required String password, required String lang}) async {
    final ref = await _api.registerStart(name: name, phone: phone, password: password, lang: lang);
    _draft = RegistrationDraft(ref: ref, name: name, phone: phone, password: password, lang: lang);
    notifyListeners();
  }

  /// There is no resend endpoint for registration codes; starting again sends
  /// a new phone code (and a new registration_ref).
  Future<void> registerResendPhoneCode() async {
    final d = _requireDraft();
    await registerStart(name: d.name, phone: d.phone, password: d.password, lang: d.lang);
  }

  /// Step 2 + 3: confirm the phone (once), then save email + governorate and
  /// send the email code.
  Future<void> registerPhoneAndEmail({required String phoneOtp, required String email, required String governorate}) async {
    final d = _requireDraft();
    if (!d.phoneVerified) {
      await _api.registerVerifyPhone(ref: d.ref, otp: phoneOtp);
      d.phoneVerified = true;
    }
    await _api.registerEmail(ref: d.ref, email: email, governorate: governorate);
    d.email = email;
    d.governorate = governorate;
    notifyListeners();
  }

  /// Re-sending step 3 mails a new code.
  Future<void> registerResendEmailCode() async {
    final d = _requireDraft();
    await _api.registerEmail(ref: d.ref, email: d.email!, governorate: d.governorate!);
  }

  /// Step 4.
  Future<void> registerVerifyEmail(String otp) async {
    final d = _requireDraft();
    await _api.registerVerifyEmail(ref: d.ref, otp: otp);
    d.emailVerified = true;
    notifyListeners();
  }

  /// Steps 5 + 6: upload the ID images, then submit for staff review.
  Future<CustomerProfile> registerDocumentsAndSubmit({required String documentType, required UploadFile front, UploadFile? back}) async {
    final d = _requireDraft();
    if (!d.documentsUploaded) {
      await _api.registerDocuments(ref: d.ref, documentType: documentType, front: front, back: back);
      d.documentsUploaded = true;
    }
    final customer = await _api.registerSubmit(d.ref);
    d.submitted = customer;
    notifyListeners();
    return customer;
  }

  /// Drop the draft (after submit, or when the session is gone).
  void clearDraft() {
    _draft = null;
    notifyListeners();
  }

  RegistrationDraft _requireDraft() {
    final d = _draft;
    if (d == null) {
      throw const ApiException(status: 410, code: 'registration_session_invalid', message: 'Start again.');
    }
    return d;
  }
}

/// In-memory state of a registration in progress. The backend keeps the
/// real state against `ref`; the password stays here only so a phone code
/// can be re-sent by restarting step 1.
class RegistrationDraft {
  RegistrationDraft({required this.ref, required this.name, required this.phone, required this.password, required this.lang});

  final String ref;
  final String name;
  final String phone;
  final String password;
  final String lang;
  bool phoneVerified = false;
  String? email;
  String? governorate;
  bool emailVerified = false;
  bool documentsUploaded = false;
  CustomerProfile? submitted;
}
