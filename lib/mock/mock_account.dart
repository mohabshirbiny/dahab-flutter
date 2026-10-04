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

const mockDevices = <DeviceSession>[
  DeviceSession(name: 'iPhone, Cairo', sub: 'This device, now', current: true),
  DeviceSession(name: 'Chrome, Cairo', sub: 'Last used 22 Aug', current: false),
];

const mockNotifications = <AppNotification>[
  AppNotification(
    icon: 'chart-line',
    tone: 'ok',
    title: 'Gold is up 2.8% since you listed',
    sub: 'Your gold necklace would now fetch 91,240 EGP · 20 minutes ago',
    target: 'listings',
  ),
  AppNotification(icon: 'alert-triangle', tone: 'bad', title: 'A buyer wants your gold necklace', sub: 'Reply before 31 Aug, 19:00 · 2 hours ago', target: 'orders'),
  AppNotification(icon: 'clock', tone: 'wait', title: '9 hours left to bring the gold ring to IGI', sub: 'Nasr City branch closes at 18:00 · 4 hours ago', target: 'orders'),
  AppNotification(icon: 'circle-check', tone: 'ok', title: 'Your earrings with stones passed inspection', sub: 'Pay the balance to collect · yesterday', target: 'pay'),
  AppNotification(icon: 'camera', tone: 'bad', title: 'We need a clearer photo of the gold pendant', sub: 'The hallmark is blurred · yesterday', target: 'listings'),
  AppNotification(
    icon: 'wallet',
    tone: 'ok',
    title: '56,952 EGP reached your wallet',
    sub: 'Gold ring sold · 28 Aug',
    // The prototype opens the invoice; its unlinked "How did it go" screen
    // is about exactly this payout, so it is reached from here.
    target: 'rate',
  ),
  AppNotification(icon: 'shield-lock', tone: 'neutral', title: 'Your payout account was confirmed', sub: 'CIB ending 4417 · 12 May', target: 'bank'),
];

List<NotificationPref> mockNotificationPrefs() => [
  NotificationPref(title: 'A buyer requests my piece', sub: 'Always on, this one has a deadline', on: true, locked: true),
  NotificationPref(title: 'Price of my listed pieces moves', on: true),
  NotificationPref(title: 'Deadline reminders', on: true),
  NotificationPref(title: 'New pieces I might like', on: false),
];

const mockFaq = <FaqItem>[
  FaqItem(
    'Why would I get more than a jeweller?',
    'A jeweller melts the piece, so he pays for the metal and keeps the craft. Here another woman buys the piece as it is, so the making charge comes back to you instead.',
  ),
  FaqItem(
    'Is this halal?',
    'Gold is handed over and paid for in the same transaction, with no interest and no borrowing. If you want to be certain for your own case, ask someone you trust for a ruling.',
  ),
  FaqItem(
    'What if my piece is lost or damaged at IGI?',
    'Pieces are insured while they are with IGI. If something happens, you are compensated and we recover it from them, not from you.',
  ),
  FaqItem(
    'When exactly do I get my money?',
    'The full amount — gold value and making charge — reaches your wallet the moment the buyer pays the balance. Withdrawals reach your bank within one working day.',
  ),
  FaqItem(
    'Why should I trust you with my gold?',
    'You never hand your piece to a stranger. It goes to IGI, a certification lab, and stays there until the buyer has paid in full. Money is held by Dahab the whole time and never passes between two people.',
  ),
  FaqItem(
    'What if nobody buys it?',
    'Nothing is charged and nothing is lost. Your piece stays listed, you can change the making charge whenever no request is open, or take it down and keep it.',
  ),
  FaqItem(
    'What if the piece turns out to be fake?',
    "If IGI finds the gold is not what it claims to be, the buyer is refunded in full from escrow straight away and the seller's account is suspended.",
  ),
  FaqItem(
    'What does it cost me?',
    'Listing is free and inspection is free. Dahab takes 20% of the making charge you recover on gold, 5% of the value you add on stones, and never less than 200 EGP.',
  ),
  FaqItem('Can I change my mind after listing?', 'Yes, as long as nobody has an open request on the piece. Once someone has asked to buy at your price, accept or decline first.'),
];

const mockBranches = <Branch>[
  Branch(
    name: 'IGI Nasr City',
    address: 'Abbas El Akkad, Cairo',
    status: 'Open now',
    open: true,
    hours: 'Sun to Thu, 10:00 to 18:00',
    closed: 'Friday and Saturday',
    duration: 'About 2 hours',
  ),
  Branch(
    name: 'IGI Mohandessin',
    address: 'Gameat El Dowal, Giza',
    status: 'Opens 11:00',
    open: false,
    hours: 'Sun to Thu, 11:00 to 19:00',
    closed: 'Friday',
    duration: 'About 3 hours',
  ),
];

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
