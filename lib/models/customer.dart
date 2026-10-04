/// Shapes returned by the Dahab customer API (`/api/v1/customer/*`).
/// Field names follow the backend Resources exactly.
library;

/// `CustomerResource` (`CustomerProfile` in the OpenAPI).
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.displayRef,
    required this.phone,
    required this.email,
    required this.emailVerifiedAt,
    required this.fullName,
    required this.preferredLang,
    required this.governorate,
    required this.status,
    required this.isVerified,
    required this.isSuspended,
    required this.suspendedReason,
    required this.tradeAllowed,
    required this.createdAt,
  });

  final String id;
  final String displayRef;
  final String phone;
  final String? email;
  final DateTime? emailVerifiedAt;
  final String? fullName;
  final String preferredLang;
  final String? governorate;

  /// pending_verification · active · rejected · suspended
  final String status;
  final bool isVerified;
  final bool isSuspended;

  /// While suspended: the backend reason code (spec 007), e.g. `off_platform_dealing`.
  /// Only the code comes to the app; the staff note never does.
  final String? suspendedReason;
  final bool tradeAllowed;
  final DateTime? createdAt;

  factory CustomerProfile.fromJson(Map<String, dynamic> j) => CustomerProfile(
    id: j['id'] as String,
    displayRef: (j['display_ref'] ?? '') as String,
    phone: (j['phone'] ?? '') as String,
    email: j['email'] as String?,
    emailVerifiedAt: _date(j['email_verified_at']),
    fullName: j['full_name'] as String?,
    preferredLang: (j['preferred_lang'] ?? 'ar') as String,
    governorate: j['governorate'] as String?,
    status: (j['status'] ?? '') as String,
    isVerified: j['is_verified'] == true,
    isSuspended: j['is_suspended'] == true,
    suspendedReason: j['suspended_reason'] as String?,
    tradeAllowed: j['trade_allowed'] == true,
    createdAt: _date(j['created_at']),
  );
}

/// `SessionDto` — access + refresh token pair.
class SessionTokens {
  const SessionTokens({required this.accessToken, required this.accessTokenExpiresAt, required this.refreshToken, required this.refreshTokenExpiresAt});

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;

  factory SessionTokens.fromJson(Map<String, dynamic> j) => SessionTokens(
    accessToken: j['access_token'] as String,
    accessTokenExpiresAt: _date(j['access_token_expires_at'])!,
    refreshToken: j['refresh_token'] as String,
    refreshTokenExpiresAt: _date(j['refresh_token_expires_at'])!,
  );
}

/// `CustomerOtpChallenge` — a sign-in held for a new device.
class OtpChallenge {
  const OtpChallenge({required this.challengeId, required this.expiresAt, required this.resendAvailableAt});

  final String challengeId;
  final DateTime expiresAt;
  final DateTime resendAvailableAt;

  factory OtpChallenge.fromJson(Map<String, dynamic> j) =>
      OtpChallenge(challengeId: j['challenge_id'] as String, expiresAt: _date(j['expires_at'])!, resendAvailableAt: _date(j['resend_available_at'])!);
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
