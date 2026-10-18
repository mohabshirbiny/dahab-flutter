import '../text_key.dart';

/// Where the identity check stands and sending the ID again (backend testing fixes, items 4–6):
/// the National ID row of Account, the "Upload your ID again" screen and the notice that stops
/// the sell form until the account is verified. `account.identity.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class AccountIdentityKeys {
  static const _area = 'Account';
  static const _row = 'Account, National ID row';
  static const _screen = 'Upload your ID again screen';
  static const _sell = 'Sell, before the form';

  // ---- The National ID row and its pill ----

  static const pillVerified = TextKey('account.identity.pill_verified', 'Verified', ar: 'متأكد منها', area: _area, where: _row);
  static const pillWaiting = TextKey('account.identity.pill_waiting', 'Waiting for review', ar: 'مستنية المراجعة', area: _area, where: _row);
  static const pillUploadAgain = TextKey('account.identity.pill_upload_again', 'Upload again', ar: 'ارفعها تاني', area: _area, where: _row);
  static const pillNotApproved = TextKey('account.identity.pill_not_approved', 'Not approved', ar: 'مااتقبلتش', area: _area, where: _row);
  static const pillMissing = TextKey('account.identity.pill_missing', 'Not sent yet', ar: 'لسه ماتبعتتش', area: _area, where: _row);

  // ---- The screen ----

  static const title = TextKey('account.identity.title', 'Upload your ID again', ar: 'ارفع بطاقتك تاني', area: _area, where: _screen);
  static const introAgain = TextKey(
    'account.identity.intro_again',
    'We could not confirm your ID from the photos you sent. Send new photos and we will check them again.',
    ar: 'ماقدرناش نتأكد من بطاقتك من الصور اللي بعتها. ابعت صور جديدة وهنراجعها تاني.',
    area: _area,
    where: _screen,
  );
  static const introRejected = TextKey(
    'account.identity.intro_rejected',
    'Your ID was not approved. You can send it again and we will check it once more.',
    ar: 'بطاقتك مااتقبلتش. تقدر تبعتها تاني وهنراجعها مرة كمان.',
    area: _area,
    where: _screen,
  );
  static const whatWasWrong = TextKey('account.identity.what_was_wrong', 'What was wrong', ar: 'إيه اللي كان غلط', area: _area, where: _screen);
  static const noteFromDahab = TextKey('account.identity.note_from_dahab', 'A note from Dahab', ar: 'ملحوظة من دهب', area: _area, where: _screen);
  static const egyptianId = TextKey('account.identity.egyptian_id', 'Egyptian ID', ar: 'بطاقة رقم قومي', area: _area, where: _screen);
  static const passport = TextKey('account.identity.passport', 'Passport', ar: 'باسبور', area: _area, where: _screen);
  static const front = TextKey('account.identity.front', 'Front', ar: 'الوش', area: _area, where: _screen);
  static const back = TextKey('account.identity.back', 'Back', ar: 'الضهر', area: _area, where: _screen);
  static const passportPage = TextKey('account.identity.passport_page', 'The page with your photo', ar: 'الصفحة اللي فيها صورتك', area: _area, where: _screen);
  static const passportBack = TextKey('account.identity.passport_back', 'Another page (optional)', ar: 'صفحة تانية (اختياري)', area: _area, where: _screen);
  static const tapToAdd = TextKey('account.identity.tap_to_add', 'Tap to add', ar: 'دوس عشان تضيف', area: _area, where: _screen);
  static const added = TextKey('account.identity.added', 'Added', ar: 'اتضافت', area: _area, where: _screen);
  static const photoTip = TextKey(
    'account.identity.photo_tip',
    'Photograph the whole card, avoid glare, and make sure the text is readable.',
    ar: 'صوّر الكارت كله، وابعد عن اللمعة، واتأكد إن الكلام مقروء.',
    area: _area,
    where: _screen,
  );
  static const send = TextKey('account.identity.send', 'Send for review', ar: 'ابعت للمراجعة', area: _area, where: _screen);
  static const photosMissing = TextKey('account.identity.photos_missing', 'Add the photos of your ID first.', ar: 'ضيف صور بطاقتك الأول.', area: _area, where: _screen);
  static const sent = TextKey(
    'account.identity.sent',
    'Sent. We will tell you as soon as it is checked.',
    ar: 'اتبعتت. هنقولك أول ما تتراجع.',
    area: _area,
    where: _screen,
  );
  static const alreadyPending = TextKey(
    'account.identity.already_pending',
    'Your ID is already waiting for review. We will tell you when it is checked.',
    ar: 'بطاقتك مستنية المراجعة بالفعل. هنقولك لما تتراجع.',
    area: _area,
    where: _screen,
  );
  static const uploadExpired = TextKey(
    'account.identity.upload_expired',
    'The photos took too long to send. Add them again and send.',
    ar: 'الصور اتأخرت في الإرسال. ضيفها تاني وابعت.',
    area: _area,
    where: _screen,
  );
  static const unsupportedKind = TextKey(
    'account.identity.unsupported_kind',
    'An Egyptian ID needs both the front and the back.',
    ar: 'بطاقة الرقم القومي محتاجة الوش والضهر.',
    area: _area,
    where: _screen,
  );
  static const notNeeded = TextKey(
    'account.identity.not_needed',
    'There is nothing to send: your ID is verified or waiting for review.',
    ar: 'مفيش حاجة تتبعت: بطاقتك متأكد منها أو مستنية المراجعة.',
    area: _area,
    where: _screen,
  );

  // ---- The reviewer's reasons (backend IdentityReviewReason) ----

  static const reasonBlurred = TextKey('account.identity.reason_blurred', 'The photo is blurred or has glare', ar: 'الصورة مش واضحة أو فيها لمعة', area: _area, where: _screen);
  static const reasonCutOff = TextKey('account.identity.reason_cut_off', 'Part of the card is cut off', ar: 'جزء من الكارت مقصوص', area: _area, where: _screen);
  static const reasonName = TextKey('account.identity.reason_name', 'The name does not match your account', ar: 'الاسم مش زي اللي على حسابك', area: _area, where: _screen);
  static const reasonExpired = TextKey('account.identity.reason_expired', 'The card has expired', ar: 'الكارت منتهي', area: _area, where: _screen);
  static const reasonBack = TextKey('account.identity.reason_back', 'The back of the card is missing', ar: 'ضهر الكارت مش موجود', area: _area, where: _screen);
  static const reasonText = TextKey('account.identity.reason_text', 'The text cannot be read', ar: 'الكلام مش مقروء', area: _area, where: _screen);

  /// The label of a backend reason code; null for a code this version does not know.
  static TextKey? reason(String code) => switch (code) {
    'blurred_or_glare' => reasonBlurred,
    'card_cut_off' => reasonCutOff,
    'name_does_not_match' => reasonName,
    'card_expired' => reasonExpired,
    'back_missing' => reasonBack,
    'text_not_readable' => reasonText,
    _ => null,
  };

  // ---- Sell: before the form ----

  static const sellWaitingTitle = TextKey('account.identity.sell_waiting_title', 'We are checking your ID', ar: 'بنراجع بطاقتك', area: _area, where: _sell);
  static const sellWaitingBody = TextKey(
    'account.identity.sell_waiting_body',
    'You can sell as soon as your ID is approved. We will tell you on your phone and email.',
    ar: 'تقدر تبيع أول ما بطاقتك تتقبل. هنقولك على الموبايل والإيميل.',
    area: _area,
    where: _sell,
  );
  static const sellAgainTitle = TextKey('account.identity.sell_again_title', 'Send your ID again to sell', ar: 'ابعت بطاقتك تاني عشان تبيع', area: _area, where: _sell);
  static const sellAgainBody = TextKey(
    'account.identity.sell_again_body',
    'We need new photos of your ID before you can list a piece.',
    ar: 'محتاجين صور جديدة لبطاقتك قبل ما تعرض قطعة.',
    area: _area,
    where: _sell,
  );
  static const sellSuspendedTitle = TextKey('account.identity.sell_suspended_title', 'Selling is paused on your account', ar: 'البيع واقف على حسابك', area: _area, where: _sell);
  static const sellClosedTitle = TextKey('account.identity.sell_closed_title', 'This account is closed', ar: 'الحساب ده مقفول', area: _area, where: _sell);

  // ---- Not approved: no new upload, contact customer service (backend rejected-identity-reopen) ----

  static const rejectedTitle = TextKey('account.identity.rejected_title', 'Your ID was not approved', ar: 'بطاقتك مااتقبلتش', area: _area, where: _screen);
  static const rejectedBody = TextKey(
    'account.identity.rejected_body',
    'You cannot send your ID again from the app. Contact customer service and they can look at it again.',
    ar: 'مش هتقدر تبعت بطاقتك تاني من التطبيق. كلّم خدمة العملاء وهم يقدروا يراجعوها تاني.',
    area: _area,
    where: _screen,
  );
  static const contactSupport = TextKey('account.identity.contact_support', 'Contact customer service', ar: 'كلّم خدمة العملاء', area: _area, where: _screen);

  static const all = <TextKey>[
    pillVerified,
    pillWaiting,
    pillUploadAgain,
    pillNotApproved,
    pillMissing,
    title,
    introAgain,
    introRejected,
    whatWasWrong,
    noteFromDahab,
    egyptianId,
    passport,
    front,
    back,
    passportPage,
    passportBack,
    tapToAdd,
    added,
    photoTip,
    send,
    photosMissing,
    sent,
    alreadyPending,
    uploadExpired,
    unsupportedKind,
    notNeeded,
    reasonBlurred,
    reasonCutOff,
    reasonName,
    reasonExpired,
    reasonBack,
    reasonText,
    sellWaitingTitle,
    sellWaitingBody,
    sellAgainTitle,
    sellAgainBody,
    sellSuspendedTitle,
    sellClosedTitle,
    rejectedTitle,
    rejectedBody,
    contactSupport,
  ];
}
