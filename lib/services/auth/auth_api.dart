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

  Future<CustomerProfile> me() async {
    final json = await _client.get('/customer/auth/me', auth: true);
    return CustomerProfile.fromJson(json!['data'] as Map<String, dynamic>);
  }

  Future<void> logout() => _client.post('/customer/auth/logout', auth: true);

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
  Future<CustomerProfile> registerSubmit(String ref) async {
    final json = await _client.post('/customer/auth/register/submit', body: {'registration_ref': ref});
    return CustomerProfile.fromJson((json!['data'] as Map<String, dynamic>)['customer'] as Map<String, dynamic>);
  }

  LoginSignedIn _signedIn(Map<String, dynamic> data) =>
      LoginSignedIn(CustomerProfile.fromJson(data['customer'] as Map<String, dynamic>), SessionTokens.fromJson(data['session'] as Map<String, dynamic>));
}
