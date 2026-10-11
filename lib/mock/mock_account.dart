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

/// Promo codes the mock accepts (both code sets that appear in the prototype).
const mockPromoCodes = <PromoCode>[
  PromoCode(code: 'WELCOME', off: 0.50, label: 'Welcome, 50% off commission', firstSaleOnly: true),
  PromoCode(code: 'EID25', off: 0.25, label: 'Eid campaign, 25% off commission'),
  PromoCode(code: 'DAHAB50', off: 0.5, label: '50% off the commission'),
  PromoCode(code: 'FIRSTSALE', off: 1, label: 'No commission on your first sale'),
  PromoCode(code: 'RAMADAN25', off: 0.25, label: '25% off the commission'),
];

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
