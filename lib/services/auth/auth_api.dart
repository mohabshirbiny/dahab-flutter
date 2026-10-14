import '../../models/customer.dart';
import '../api/api_client.dart';

/// Result of `POST /customer/auth/login`: either a session (trusted device)
/// or an SMS challenge (new device).
sealed class LoginResult {
  const LoginResult();
}

class LoginSignedIn extends LoginResult {
  const LoginSignedIn(this.customer, this.session);
  final CustomerProfile customer;
  final SessionTokens session;
}

class LoginNeedsOtp extends LoginResult {
  const LoginNeedsOtp(this.challenge);
  final OtpChallenge challenge;
}

/// Answer of `POST /customer/auth/password/reset-request` (backend spec 020): the same for any
/// phone, so nothing here says whether the number is registered.
class PasswordResetRequested {
  const PasswordResetRequested({required this.expiresInSeconds, required this.resendAvailableAt});

  final int expiresInSeconds;
  final DateTime resendAvailableAt;

  factory PasswordResetRequested.fromJson(Map<String, dynamic> j) => PasswordResetRequested(
    expiresInSeconds: (j['expires_in_seconds'] as num?)?.toInt() ?? 300,
    resendAvailableAt: DateTime.tryParse(j['resend_available_at'] as String? ?? '')?.toLocal() ?? DateTime.now().add(const Duration(seconds: 60)),
  );
}

/// Answer of `POST /customer/auth/password/reset-confirm`: no session is issued.
class PasswordResetDone {
  const PasswordResetDone({required this.signedOutSessions, required this.withdrawalsPausedUntil, required this.cancelledWithdrawals});

  final int signedOutSessions;

  /// Null when the withdrawal pause setting is 0.
  final DateTime? withdrawalsPausedUntil;
  final int cancelledWithdrawals;

  factory PasswordResetDone.fromJson(Map<String, dynamic> j) => PasswordResetDone(
    signedOutSessions: (j['signed_out_sessions'] as num?)?.toInt() ?? 0,
    withdrawalsPausedUntil: DateTime.tryParse(j['withdrawals_paused_until'] as String? ?? '')?.toLocal(),
    cancelledWithdrawals: (j['cancelled_withdrawals'] as num?)?.toInt() ?? 0,
  );
}

/// Typed calls to the customer auth + registration endpoints in
/// `dahab-backend/routes/api.php`. Request and response fields mirror the
/// FormRequests and controller responses there.
class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  // ---- sign-in ----

  Future<LoginResult> login({required String phone, required String password}) async {
    final json = await _client.post('/customer/auth/login', body: {'phone': phone, 'password': password});
    final data = json!['data'] as Map<String, dynamic>;
    if (data['otp_required'] == true) return LoginNeedsOtp(OtpChallenge.fromJson(data));
    return _signedIn(data);
  }

  Future<LoginSignedIn> verifyLoginOtp({required String challengeId, required String code}) async {
    final json = await _client.post('/customer/auth/otp/verify', body: {'challenge_id': challengeId, 'code': code});
    return _signedIn(json!['data'] as Map<String, dynamic>);
  }

  Future<OtpChallenge> resendLoginOtp(String challengeId) async {
    final json = await _client.post('/customer/auth/otp/resend', body: {'challenge_id': challengeId});
    return OtpChallenge.fromJson(json!['data'] as Map<String, dynamic>);
  }

  // ---- forgot password (backend spec 020) ----

  /// Texts a code to the phone when it belongs to an open account; answers the same either way.
  Future<PasswordResetRequested> passwordResetRequest(String phone) async {
    final json = await _client.post('/customer/auth/password/reset-request', body: {'phone': phone});
    return PasswordResetRequested.fromJson(json!['data'] as Map<String, dynamic>);
  }

  /// Spends the code and sets the new password; every session and device is signed out.
  Future<PasswordResetDone> passwordResetConfirm({required String phone, required String code, required String password}) async {
    final json = await _client.post(
      '/customer/auth/password/reset-confirm',
      body: {'phone': phone, 'code': code, 'password': password, 'password_confirmation': password},
    );
    return PasswordResetDone.fromJson(json!['data'] as Map<String, dynamic>);
  }

  Future<CustomerProfile> me() async {
    final json = await _client.get('/customer/auth/me', auth: true);
    return CustomerProfile.fromJson(json!['data'] as Map<String, dynamic>);
  }

  /// Backend testing fixes item 5: one identity photo, `POST /customer/me/uploads`
  /// (`purpose=identity`). Returns the upload token.
  Future<String> uploadIdentity(UploadFile file) async {
    final json = await _client.postMultipart('/customer/me/uploads', fields: {'purpose': 'identity'}, files: [file], auth: true);
    return '${(json!['data'] as Map)['upload_token']}';
  }

  /// A new identity attempt: `POST /customer/me/identity-documents`. Refusals:
  /// `document_already_pending` (409), `upload_token_invalid`, `unsupported_doc_kind` (422).
  Future<void> submitIdentity({required String docKind, required String frontToken, String? backToken}) => _client.post(
    '/customer/me/identity-documents',
    body: {'doc_kind': docKind, 'front_upload_token': frontToken, 'back_upload_token': ?backToken},
    auth: true,
  );

  Future<void> logout() => _client.post('/customer/auth/logout', auth: true);

  /// Revokes every token issued to the customer, this device's too.
  Future<void> logoutAll() => _client.post('/customer/auth/logout-all', auth: true);

  // ---- registration (six steps; the UI shows them as three screens) ----

  /// Step 1 — returns the `registration_ref`.
  Future<String> registerStart({required String name, required String phone, required String password, required String lang}) async {
    final json = await _client.post(
      '/customer/auth/register/start',
      body: {'name': name, 'phone': phone, 'password': password, 'password_confirmation': password, 'preferred_lang': lang},
    );
    return (json!['data'] as Map<String, dynamic>)['registration_ref'] as String;
  }

  /// Step 2.
  Future<void> registerVerifyPhone({required String ref, required String otp}) =>
      _client.post('/customer/auth/register/verify-phone-otp', body: {'registration_ref': ref, 'otp': otp});

  /// Step 3 — sends the email code.
  Future<void> registerEmail({required String ref, required String email, required String governorate}) =>
      _client.post('/customer/auth/register/email', body: {'registration_ref': ref, 'email': email, 'governorate': governorate});

  /// Step 4.
  Future<void> registerVerifyEmail({required String ref, required String otp}) =>
      _client.post('/customer/auth/register/verify-email-otp', body: {'registration_ref': ref, 'otp': otp});

  /// Step 5 — `egyptian_id` needs front + back; `passport` front only.
  Future<void> registerDocuments({required String ref, required String documentType, required UploadFile front, UploadFile? back}) =>
      _client.postMultipart('/customer/auth/register/documents', fields: {'registration_ref': ref, 'document_type': documentType}, files: [front, ?back]);

  /// Step 6 — creates the customer as `pending_verification`; no session.
  ///
  /// Sends the ids of the live `terms` and `privacy` versions (backend spec 019) so the sign-up
  /// acceptance is recorded. A document that is not published, or any failure reading it, sends
  /// no id: the customer then meets the first-acceptance screen at their first sign-in.
  Future<CustomerProfile> registerSubmit(String ref) async {
    final terms = await _liveLegalId('terms');
    final privacy = await _liveLegalId('privacy');
    final json = await _client.post(
      '/customer/auth/register/submit',
      body: {'registration_ref': ref, 'terms_legal_doc_id': ?terms, 'privacy_legal_doc_id': ?privacy},
    );
    return CustomerProfile.fromJson((json!['data'] as Map<String, dynamic>)['customer'] as Map<String, dynamic>);
  }

  Future<int?> _liveLegalId(String code) async {
    try {
      final json = await _client.get('/reference/legal-documents/$code');
      return ((json?['data'] as Map?)?['id'] as num?)?.toInt();
    } on ApiException {
      return null;
    }
  }

  /// Accepts the live terms or privacy the customer was shown (backend spec 019).
  Future<void> acceptLegal(int legalDocId, {required String idempotencyKey}) =>
      _client.post('/customer/me/legal-acceptances', body: {'legal_doc_id': legalDocId}, auth: true, idempotencyKey: idempotencyKey);

  LoginSignedIn _signedIn(Map<String, dynamic> data) =>
      LoginSignedIn(CustomerProfile.fromJson(data['customer'] as Map<String, dynamic>), SessionTokens.fromJson(data['session'] as Map<String, dynamic>));
}
