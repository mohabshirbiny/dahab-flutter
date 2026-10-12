import '../text_key.dart';

/// Codes on the sell form, the paid-early note and the order's advance (backend spec 023). `promo.*`.
///
/// English is the code's own text. The Arabic defaults are AR-DRAFT: written for the owner's review
/// (the Egyptian wording of the app), published only through App text. Keys are append-only.
abstract final class PromoKeys {
  static const _area = 'Selling';

  static const cardTitle = TextKey('promo.card.title', 'Promo code', ar: 'كود خصم', area: _area, where: 'Promo card');
  static const cardHint = TextKey(
    'promo.card.hint',
    'If you have a promo code, enter it here.',
    ar: 'لو معاك كود خصم اكتبه هنا.',
    area: _area,
    where: 'Promo card',
  );
  static const cardApply = TextKey('promo.card.apply', 'Apply', ar: 'تطبيق', area: _area, where: 'Promo card');
  static const cardRemove = TextKey('promo.card.remove', 'Remove', ar: 'شيل الكود', area: _area, where: 'Promo card');
  static const cardEnterFirst = TextKey('promo.card.enter_first', 'Enter a code first.', ar: 'اكتب الكود الأول.', area: _area, where: 'Promo card');
  static const resultPercent = TextKey(
    'promo.result.percent',
    '{percent}% off the commission',
    ar: 'خصم {percent}% على العمولة',
    placeholders: ['percent'],
    area: _area,
    where: 'Promo card',
  );
  static const resultWaive = TextKey('promo.result.waive', 'No commission on this sale', ar: 'من غير عمولة على البيعة دي', area: _area, where: 'Promo card');
  static const resultAmount = TextKey(
    'promo.result.amount',
    '{amount} off the commission',
    ar: 'خصم {amount} من العمولة',
    placeholders: ['amount'],
    area: _area,
    where: 'Promo card',
  );
  static const resultMinimum = TextKey(
    'promo.result.minimum',
    'The {minimum} EGP minimum commission still applies.',
    ar: 'الحد الأدنى للعمولة {minimum} جنيه لسه ساري.',
    placeholders: ['minimum'],
    area: _area,
    where: 'Promo card',
  );
  static const resultFirstSaleOnly = TextKey(
    'promo.result.first_sale_only',
    'For your first sale only.',
    ar: 'للبيعة الأولى بس.',
    area: _area,
    where: 'Promo card',
  );
  static const resultApplied = TextKey('promo.result.applied', 'Applied to this piece.', ar: 'اتطبّق على القطعة دي.', area: _area, where: 'Promo card');
  static const resultRemoved = TextKey('promo.result.removed', 'Code removed.', ar: 'الكود اتشال.', area: _area, where: 'Promo card');
  static const resultCreditWaiting = TextKey(
    'promo.result.credit_waiting',
    'You have {amount} of commission credit. It is used on your next sale.',
    ar: 'عندك رصيد عمولة {amount}. هيتخصم من بيعتك الجاية.',
    placeholders: ['amount'],
    area: _area,
    where: 'Promo card',
  );
  static const estimateSaving = TextKey('promo.estimate.saving', 'Promo saving', ar: 'توفير الكود', area: _area, where: 'Sell step 1');
  static const advanceAvailable = TextKey(
    'promo.advance.available',
    'Paid as soon as IGI confirms your piece, up to {cap}.',
    ar: 'هتتدفعلك أول ما IGI تأكد القطعة، لحد {cap}.',
    placeholders: ['cap'],
    area: _area,
    where: 'Sell step 3',
  );
  static const advanceNotFirstGold = TextKey(
    'promo.advance.not_first_gold',
    'This code pays a first gold sale early. This is not your first gold sale.',
    ar: 'الكود ده بيدفع أول بيعة دهب بدري. دي مش أول بيعة دهب ليك.',
    area: _area,
    where: 'Sell step 3',
  );
  static const advanceUnavailable = TextKey(
    'promo.advance.unavailable',
    'Paying you early is not available right now. You are paid when the buyer pays.',
    ar: 'الدفع بدري مش متاح دلوقتي. هتتدفعلك لما المشتري يدفع.',
    area: _area,
    where: 'Sell step 3',
  );
  static const errUnknown = TextKey('promo.error.unknown', 'That code is not valid.', ar: 'الكود ده مش صحيح.', area: _area, where: 'Promo card');
  static const errNotStarted = TextKey(
    'promo.error.not_started',
    'This code has not started yet.',
    ar: 'الكود ده لسه ما بدأش.',
    area: _area,
    where: 'Promo card',
  );
  static const errEnded = TextKey('promo.error.ended', 'This code has ended.', ar: 'الكود ده خلص.', area: _area, where: 'Promo card');
  static const errFirstSaleOnly = TextKey(
    'promo.error.first_sale_only',
    'This code is for your first sale only.',
    ar: 'الكود ده لأول بيعة ليك بس.',
    area: _area,
    where: 'Promo card',
  );
  static const errAlreadyUsed = TextKey(
    'promo.error.already_used',
    'You have already used this code.',
    ar: 'إنت استخدمت الكود ده قبل كده.',
    area: _area,
    where: 'Promo card',
  );
  static const errCapReached = TextKey(
    'promo.error.cap_reached',
    'This code has reached its limit for the month.',
    ar: 'الكود ده وصل للحد بتاعه الشهر ده.',
    area: _area,
    where: 'Promo card',
  );
  static const errNotOpen = TextKey('promo.error.not_open', 'Codes are not open yet.', ar: 'الأكواد لسه ما اتفتحتش.', area: _area, where: 'Promo card');
  static const errOwnReferral = TextKey(
    'promo.error.own_referral',
    'You cannot use your own invitation code.',
    ar: 'ما تقدرش تستخدم كود الدعوة بتاعك.',
    area: _area,
    where: 'Promo card',
  );
  static const errReferralJoined = TextKey(
    'promo.error.referral_joined',
    'You have already joined with an invitation code.',
    ar: 'إنت انضممت بكود دعوة قبل كده.',
    area: _area,
    where: 'Promo card',
  );
  static const errReferralFull = TextKey(
    'promo.error.referral_full',
    'This invitation code has reached its limit.',
    ar: 'كود الدعوة ده وصل للحد بتاعه.',
    area: _area,
    where: 'Promo card',
  );
  static const errDeviceLimit = TextKey(
    'promo.error.device_limit',
    'This device has already been used with an invitation code.',
    ar: 'الجهاز ده اتستخدم قبل كده مع كود دعوة.',
    area: _area,
    where: 'Promo card',
  );
  static const errLocked = TextKey(
    'promo.error.locked',
    'The code cannot change once a buyer has asked for the piece.',
    ar: 'الكود ما يتغيّرش بعد ما مشتري يطلب القطعة.',
    area: _area,
    where: 'Promo card',
  );
  static const orderAdvancePaid = TextKey('promo.order.advance_paid', 'Advance paid', ar: 'السلفة اتدفعت', area: _area, where: 'Order');
  static const orderAdvanceNote = TextKey(
    'promo.order.advance_note',
    '{amount} reached your wallet when IGI confirmed your piece. The rest follows when the buyer pays.',
    ar: '{amount} وصلوا محفظتك لما IGI أكدت القطعة. الباقي بيوصل لما المشتري يدفع.',
    placeholders: ['amount'],
    area: _area,
    where: 'Order',
  );
  static const orderPaidEarlier = TextKey('promo.order.paid_earlier', 'Paid earlier', ar: 'اتدفع بدري', area: _area, where: 'Order');
  static const orderCommissionSaved = TextKey(
    'promo.order.commission_saved',
    'You saved {amount} on the commission',
    ar: 'وفّرت {amount} من العمولة',
    placeholders: ['amount'],
    area: _area,
    where: 'Order',
  );
  static const orderWithCode = TextKey(
    'promo.order.commission_with_code',
    'with code {code}',
    ar: 'بكود {code}',
    placeholders: ['code'],
    area: _area,
    where: 'Order',
  );
  static const orderWithCredit = TextKey(
    'promo.order.commission_with_credit',
    'with your commission credit',
    ar: 'برصيد العمولة بتاعك',
    area: _area,
    where: 'Order',
  );

  static const releasedLabel = TextKey('promo.advance.released_label', 'Money released', ar: 'الفلوس بتتحرر', area: _area, where: 'Sell step 3');

  static const all = <TextKey>[
    releasedLabel,
    cardTitle,
    cardHint,
    cardApply,
    cardRemove,
    cardEnterFirst,
    resultPercent,
    resultWaive,
    resultAmount,
    resultMinimum,
    resultFirstSaleOnly,
    resultApplied,
    resultRemoved,
    resultCreditWaiting,
    estimateSaving,
    advanceAvailable,
    advanceNotFirstGold,
    advanceUnavailable,
    errUnknown,
    errNotStarted,
    errEnded,
    errFirstSaleOnly,
    errAlreadyUsed,
    errCapReached,
    errNotOpen,
    errOwnReferral,
    errReferralJoined,
    errReferralFull,
    errDeviceLimit,
    errLocked,
    orderAdvancePaid,
    orderAdvanceNote,
    orderPaidEarlier,
    orderCommissionSaved,
    orderWithCode,
    orderWithCredit,
  ];
}
