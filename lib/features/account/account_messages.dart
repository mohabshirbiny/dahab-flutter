import '../../services/api/api_client.dart';
import '../../services/auth/auth_messages.dart';

/// English source text for the account's refusals (backend spec 017),
/// translated by the UI with `t()`; anything else falls back to [authErrorMessage].
String accountErrorMessage(ApiException e) => switch (e.code) {
  'contact_taken' => 'This number or address is already used by another account.',
  'same_contact' => 'This is already your number or address.',
  'change_code_invalid' => 'That code is not right or has expired.',
  'change_code_locked' => 'Too many wrong codes. Ask for a new one.',
  'change_link_invalid' => 'This link has expired or was already used.',
  'current_password_wrong' => 'Your current password is not right.',
  'current_session' => 'This is the device you are using. Sign out instead.',
  'account_has_open_items' => 'Finish or cancel what is in progress before closing the account.',
  'listing_not_saveable' => 'Only a piece on the market can be saved.',
  'saved_limit_reached' => 'You have saved as many pieces as you can. Remove one first.',
  'listing_not_reportable' => 'This piece cannot be reported.',
  'report_already_open' => 'You already reported this piece. We are looking at it.',
  'validation_failed' => e.fieldErrors.values.expand((v) => v).firstOrNull ?? authErrorMessage(e),
  _ => authErrorMessage(e),
};
