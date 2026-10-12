import '../models/account.dart';

const mockProfile = UserProfile(
  displayName: 'Mona Hassan',
  fullName: 'Mona Hassan Ibrahim',
  sellerId: 'Seller 4417',
  memberSince: 'May 2026',
  phoneMasked: '+20 10 •••• 4417',
  email: 'mona.h@email.com',
  payoutShort: 'CIB ••4417',
  inviteCode: 'MONA4417',
);

/// Countries offered in the phone-number pickers.
const mockCountryCodes = <(String, String)>[
  ('+20', '🇪🇬 +20'),
  ('+971', '🇦🇪 +971'),
  ('+966', '🇸🇦 +966'),
  ('+965', '🇰🇼 +965'),
  ('+974', '🇶🇦 +974'),
  ('+44', '🇬🇧 +44'),
  ('+1', '🇺🇸 +1'),
  ('+39', '🇮🇹 +39'),
];
