import '../text_key.dart';

/// *Invite a friend* (backend spec 023 Story 4). `referral.*`. The figures in the sentences are
/// setting placeholders (`{referral_friend_pct}`, …), so a changed setting changes the words.
///
/// The Arabic defaults are AR-DRAFT, for the owner's review. Keys are append-only.
abstract final class ReferralKeys {
  static const _area = 'Account';

  static const menuSub = TextKey(
    'referral.menu_sub',
    'Both of you pay less commission',
    ar: 'إنتوا الاتنين بتدفعوا عمولة أقل',
    area: _area,
    where: 'Account menu',
  );
  static const title = TextKey('referral.title', 'Invite a friend', ar: 'ادعو صاحبك', area: _area, where: 'Invite a friend');
  static const intro = TextKey(
    'referral.intro',
    'She pays {referral_friend_pct}% less commission on her first sale. You get {referral_reward_egp} EGP off yours.',
    ar: 'هي بتدفع عمولة أقل {referral_friend_pct}% على أول بيعة. وإنت بتاخد {referral_reward_egp} جنيه خصم من عمولتك.',
    placeholders: ['referral_friend_pct', 'referral_reward_egp'],
    area: _area,
    where: 'Invite a friend',
  );
  static const yourCode = TextKey('referral.your_code', 'Your code', ar: 'الكود بتاعك', area: _area, where: 'Invite a friend');
  static const share = TextKey('referral.share', 'Share', ar: 'شارك', area: _area, where: 'Invite a friend');
  static const copy = TextKey('referral.copy', 'Copy', ar: 'انسخ', area: _area, where: 'Invite a friend');
  static const copied = TextKey('referral.copied', 'Copied.', ar: 'اتنسخ.', area: _area, where: 'Invite a friend');
  static const shareReady = TextKey('referral.share_ready', 'Ready to share.', ar: 'جاهز للمشاركة.', area: _area, where: 'Invite a friend');
  static const shareMessage = TextKey(
    'referral.share_message',
    'Sell your gold on Dahab with my code {code} and pay less commission on your first sale.',
    ar: 'بيع دهبك على دهب بكودي {code} وادفع عمولة أقل على أول بيعة.',
    placeholders: ['code'],
    area: _area,
    where: 'Invite a friend',
  );
  static const stands = TextKey('referral.stands', 'Where it stands', ar: 'موقفك دلوقتي', area: _area, where: 'Invite a friend');
  static const invitesSent = TextKey('referral.invites_sent', 'Invites sent', ar: 'الدعوات المبعوتة', area: _area, where: 'Invite a friend');
  static const joined = TextKey('referral.joined', 'Joined', ar: 'انضموا', area: _area, where: 'Invite a friend');
  static const sold = TextKey('referral.sold', 'Sold something', ar: 'باعوا', area: _area, where: 'Invite a friend');
  static const earned = TextKey('referral.earned', 'Earned so far', ar: 'اللي كسبته لحد دلوقتي', area: _area, where: 'Invite a friend');
  static const available = TextKey('referral.available', 'Available now', ar: 'المتاح دلوقتي', area: _area, where: 'Invite a friend');
  static const expires = TextKey('referral.expires', 'Expires {date}', ar: 'بينتهي {date}', placeholders: ['date'], area: _area, where: 'Invite a friend');
  static const rewardNote = TextKey(
    'referral.reward_note',
    'The reward lands as commission credit after your friend completes her first sale, not when she signs up. It lasts {referral_expiry_days} days.',
    ar: 'المكافأة بتوصل رصيد عمولة بعد ما صاحبك تكمّل أول بيعة، مش لما تسجّل. وبتفضل {referral_expiry_days} يوم.',
    placeholders: ['referral_expiry_days'],
    area: _area,
    where: 'Invite a friend',
  );
  static const notAvailable = TextKey(
    'referral.not_available',
    'Invitations are not open yet.',
    ar: 'الدعوات لسه ما اتفتحتش.',
    area: _area,
    where: 'Invite a friend',
  );
  static const loadFailed = TextKey(
    'referral.load_failed',
    'Your invitation details could not be loaded.',
    ar: 'مقدرناش نحمّل تفاصيل الدعوة.',
    area: _area,
    where: 'Invite a friend',
  );
  static const rateCardTitle = TextKey(
    'referral.rate_card_title',
    'Know someone with gold in a drawer?',
    ar: 'تعرف حد عنده دهب في الدرج؟',
    area: _area,
    where: 'Rating',
  );
  static const rateCardBody = TextKey(
    'referral.rate_card_body',
    'Share your code. She pays less commission on her first sale, and so do you on your next.',
    ar: 'شارك كودك. هي بتدفع عمولة أقل على أول بيعة، وإنت كمان على اللي بعدها.',
    area: _area,
    where: 'Rating',
  );
  static const rateCardButton = TextKey('referral.rate_card_button', 'See my code', ar: 'شوف كودي', area: _area, where: 'Rating');

  static const all = <TextKey>[
    menuSub,
    title,
    intro,
    yourCode,
    share,
    copy,
    copied,
    shareReady,
    shareMessage,
    stands,
    invitesSent,
    joined,
    sold,
    earned,
    available,
    expires,
    rewardNote,
    notAvailable,
    loadFailed,
    rateCardTitle,
    rateCardBody,
    rateCardButton,
  ];
}
