import '../api/api_client.dart';

/// English source text for an API error (translated by the UI with `t()`).
/// Codes come from `App\Enums\AuthErrorCode` in the backend.
String authErrorMessage(ApiException e) {
  switch (e.code) {
    case 'network_error':
      return "Can't reach Dahab right now. Check your connection and try again.";
    case 'invalid_credentials':
      return 'The phone number or password is not right.';
    // Since backend spec 002 an unverified (pending or rejected) customer can sign
    // in; these two are only sent by older servers.
    case 'account_pending_verification':
      return 'Your account is still being checked. Try again once we have verified your identity.';
    case 'account_rejected':
      return 'We could not verify your identity, so this account was not approved. Contact us for help.';
    // Returned when an unverified customer tries something that needs verification
    // (buying, selling, adding funds).
    case 'verification_required':
      return 'Verify your identity before doing this. We will tell you as soon as your ID is approved.';
    case 'account_suspended':
      return 'This account is suspended. Contact us for help.';
    case 'account_locked':
      return 'Too many attempts. Wait a few minutes and try again.';
    case 'too_many_requests':
      return 'Too many requests. Wait a minute and try again.';
    case 'otp_invalid':
      return 'That code is not right. Check the message and try again.';
    case 'otp_expired':
      return 'That code has expired. Ask for a new one.';
    case 'registration_session_invalid':
    case 'registration_session_expired':
    case 'registration_session_consumed':
      return 'This sign-up took too long and has expired. Please start again.';
    case 'registration_phone_unverified':
      return 'Confirm your phone number first.';
    case 'registration_email_unverified':
      return 'Confirm your email address first.';
    case 'registration_document_missing':
      return 'Add the photos of your ID first.';
    case 'registration_already_submitted':
      return 'This sign-up was already sent for review.';
    case 'validation_failed':
      final first = e.fieldErrors.values.expand((v) => v).firstOrNull;
      return first ?? 'Check the details and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/// True when the error means the registration must start over.
bool isRegistrationGone(ApiException e) => e.code == 'registration_session_invalid' || e.code == 'registration_session_expired' || e.code == 'registration_session_consumed';

/// E.164 from the country code picker and the typed number:
/// "+20" + "010 1234 4417" → "+201012344417".
String toE164(String countryCode, String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');
  return '$countryCode$digits';
}

/// "+201012344417" → "+20 10 •••• 4417" (as shown in the prototype).
String maskPhone(String e164) {
  const codes = ['+971', '+966', '+965', '+974', '+20', '+44', '+39', '+1'];
  final cc = codes.firstWhere(e164.startsWith, orElse: () => '');
  final rest = e164.substring(cc.length);
  if (cc.isEmpty || rest.length < 7) return e164;
  return '$cc ${rest.substring(0, 2)} •••• ${rest.substring(rest.length - 4)}';
}
