import '../text_key.dart';

/// Owner notes of 2026-10-25 (backend `docs/features/offer-details-and-invoices.md`): a branch's
/// details, what a stone is and whether it has a certificate, the gold rate on the sell estimate,
/// the buyer's code as a discount, and the waived commission on the seller's invoice.
/// `branch.*`, `stone.*`, `sell.gold_value_at`, `order.promo.*`, `invoice.waived.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class OfferDetailsKeys {
  static const _branch = 'Branch details';
  static const _piece = 'Piece page and order';
  static const _pay = 'Order: pay the balance';
  static const _invoice = 'Invoice';

  // ---- A branch: hours, address, phone, map ----

  static const branchDetails = TextKey('branch.details', 'Hours and address', ar: 'المواعيد والعنوان', area: 'Shared', where: _branch);
  static const branchAddress = TextKey('branch.address', 'Address', ar: 'العنوان', area: 'Shared', where: _branch);
  static const branchHours = TextKey('branch.hours', 'Opening hours', ar: 'مواعيد العمل', area: 'Shared', where: _branch);
  static const branchClosed = TextKey('branch.closed', 'Closed', ar: 'مقفول', area: 'Shared', where: _branch);
  static const branchPhone = TextKey('branch.phone', 'Phone', ar: 'التليفون', area: 'Shared', where: _branch);
  static const branchCall = TextKey('branch.call', 'Call', ar: 'اتصل', area: 'Shared', where: _branch);
  static const branchMap = TextKey('branch.map', 'Open the map', ar: 'افتح الخريطة', area: 'Shared', where: _branch);
  static const branchNoHours = TextKey('branch.no_hours', 'Hours not set yet.', ar: 'المواعيد لسه متحددتش.', area: 'Shared', where: _branch);
  static const day0 = TextKey('branch.day_0', 'Sunday', ar: 'الأحد', area: 'Shared', where: _branch);
  static const day1 = TextKey('branch.day_1', 'Monday', ar: 'الاتنين', area: 'Shared', where: _branch);
  static const day2 = TextKey('branch.day_2', 'Tuesday', ar: 'التلات', area: 'Shared', where: _branch);
  static const day3 = TextKey('branch.day_3', 'Wednesday', ar: 'الأربع', area: 'Shared', where: _branch);
  static const day4 = TextKey('branch.day_4', 'Thursday', ar: 'الخميس', area: 'Shared', where: _branch);
  static const day5 = TextKey('branch.day_5', 'Friday', ar: 'الجمعة', area: 'Shared', where: _branch);
  static const day6 = TextKey('branch.day_6', 'Saturday', ar: 'السبت', area: 'Shared', where: _branch);
  static const days = [day0, day1, day2, day3, day4, day5, day6];

  // ---- The stone and its certificate ----

  static const certificate = TextKey('stone.certificate', 'Certificate', ar: 'الشهادة', area: 'Home', where: _piece);
  static const certIgi = TextKey('stone.cert_igi', 'IGI certificate', ar: 'شهادة IGI', area: 'Home', where: _piece);
  static const certOther = TextKey('stone.cert_other', "Another lab's certificate", ar: 'شهادة من معمل تاني', area: 'Home', where: _piece);
  static const certNone = TextKey('stone.cert_none', 'No certificate', ar: 'من غير شهادة', area: 'Home', where: _piece);
  static const certNoneNote = TextKey(
    'stone.cert_none_note',
    'This piece comes without a certificate. IGI examines the stone at handover and issues one.',
    ar: 'القطعة دي من غير شهادة. IGI بيفحص الحجر عند التسليم ويطلع له شهادة.',
    area: 'Home',
    where: _piece,
  );
  static const stoneWeight = TextKey('stone.weight', 'Stone weight', ar: 'وزن الحجر', area: 'Home', where: _piece);
  static const clarity = TextKey('stone.clarity', 'Clarity', ar: 'النقاء', area: 'Home', where: _piece);
  static const cut = TextKey('stone.cut', 'Cut', ar: 'القطع', area: 'Home', where: _piece);
  static const cutExcellent = TextKey('stone.cut_excellent', 'Excellent', ar: 'ممتاز', area: 'Home', where: _piece);
  static const cutVeryGood = TextKey('stone.cut_very_good', 'Very good', ar: 'جيد جدًا', area: 'Home', where: _piece);
  static const cutGood = TextKey('stone.cut_good', 'Good', ar: 'جيد', area: 'Home', where: _piece);
  static const stated = TextKey(
    'stone.stated',
    'As the seller states it. IGI checks it at handover.',
    ar: 'زي ما البايع كاتب. IGI بيتأكد منه عند التسليم.',
    area: 'Home',
    where: _piece,
  );
  static const feeNone = TextKey('stone.fee_none', 'IGI certificate (you have none)', ar: 'شهادة IGI (معندكش شهادة)', area: 'Selling', where: 'Your listing');
  static const feeOther = TextKey(
    'stone.fee_other',
    "IGI certificate (you have another lab's)",
    ar: 'شهادة IGI (عندك شهادة معمل تاني)',
    area: 'Selling',
    where: 'Your listing',
  );
  static const feeIgi = TextKey('stone.fee_igi', 'IGI certificate', ar: 'شهادة IGI', area: 'Selling', where: 'Your listing');

  // ---- The sell estimate ----

  static const goldValueAt = TextKey(
    'sell.gold_value_at',
    'Gold value at {rate} per gram',
    ar: 'قيمة الدهب بسعر {rate} للجرام',
    placeholders: ['rate'],
    area: 'Selling',
    where: 'Sell step 1',
  );

  // ---- The buyer's code on the order ----

  static const price = TextKey('order.promo.price', 'Price', ar: 'السعر', area: 'Orders', where: _pay);
  static const discount = TextKey('order.promo.discount', 'Discount, code {code}', ar: 'خصم الكود {code}', placeholders: ['code'], area: 'Orders', where: _pay);
  static const totalAfter = TextKey('order.promo.total', 'Total after discount', ar: 'الإجمالي بعد الخصم', area: 'Orders', where: _pay);
  static const spreadNote = TextKey(
    'order.promo.spread_note',
    'Your code {code} gives you the price the seller gets: {amount} off.',
    ar: 'الكود {code} بيديك سعر البايع: خصم {amount}.',
    placeholders: ['code', 'amount'],
    area: 'Orders',
    where: _pay,
  );
  static const indicative = TextKey(
    'order.promo.indicative',
    'The final figures follow the weight IGI measures.',
    ar: 'الأرقام النهائية حسب الوزن اللي IGI يقيسه.',
    area: 'Orders',
    where: _pay,
  );
  static const depositFull = TextKey('order.promo.deposit_full', 'Deposit before the code', ar: 'العربون قبل الكود', area: 'Orders', where: _pay);
  static const depositDiscount = TextKey(
    'order.promo.deposit_discount',
    'Deposit discount, code {code}',
    ar: 'خصم العربون بالكود {code}',
    placeholders: ['code'],
    area: 'Orders',
    where: _pay,
  );

  // ---- The seller's invoice of a sale with a waived commission ----

  static const ordinaryCommission = TextKey(
    'invoice.waived.ordinary',
    'Commission on an ordinary sale, VAT included',
    ar: 'العمولة في البيع العادي شاملة الضريبة',
    area: 'Wallet',
    where: _invoice,
  );
  static const waivedFreeRelist = TextKey('invoice.waived.free_relist', 'Free relist', ar: 'إعادة عرض مجانية', area: 'Wallet', where: _invoice);
  static const waivedDealer = TextKey('invoice.waived.market_maker', 'Dealer purchase', ar: 'شراء تاجر', area: 'Wallet', where: _invoice);
  static const waivedCode = TextKey(
    'invoice.waived.code',
    'Promo code {code}',
    ar: 'كود الخصم {code}',
    placeholders: ['code'],
    area: 'Wallet',
    where: _invoice,
  );
  static const waivedCredit = TextKey('invoice.waived.credit', 'Your commission credit', ar: 'رصيد العمولة بتاعك', area: 'Wallet', where: _invoice);

  static const all = <TextKey>[
    branchDetails,
    branchAddress,
    branchHours,
    branchClosed,
    branchPhone,
    branchCall,
    branchMap,
    branchNoHours,
    ...days,
    certificate,
    certIgi,
    certOther,
    certNone,
    certNoneNote,
    stoneWeight,
    clarity,
    cut,
    cutExcellent,
    cutVeryGood,
    cutGood,
    stated,
    feeNone,
    feeOther,
    feeIgi,
    goldValueAt,
    price,
    discount,
    totalAfter,
    spreadNote,
    indicative,
    depositFull,
    depositDiscount,
    ordinaryCommission,
    waivedFreeRelist,
    waivedDealer,
    waivedCode,
    waivedCredit,
  ];
}
