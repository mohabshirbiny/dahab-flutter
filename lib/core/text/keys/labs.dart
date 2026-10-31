import '../text_key.dart';

/// Labs and what they cost (backend `docs/features/labs-and-certificate-costs.md`): the certificate
/// the seller holds, the lab and branch they choose, and what the lab costs them.
/// `labs.*`. The Arabic defaults are AR-DRAFT: written for the owner's review.
/// Keys are append-only (Q1).
abstract final class LabKeys {
  static const _sell = 'Sell step 1: certificate and lab';
  static const _piece = 'A seller\'s piece';

  static const certificateQuestion = TextKey('labs.certificate_question', 'Which certificate do you have?', ar: 'معاك شهادة من أنهي معمل؟', area: 'Selling', where: _sell);
  static const anotherLab = TextKey('labs.another_lab', 'Another lab', ar: 'معمل تاني', area: 'Selling', where: _sell);
  static const noCertificate = TextKey('labs.no_certificate', 'No certificate', ar: 'من غير شهادة', area: 'Selling', where: _sell);
  static const otherLabName = TextKey('labs.other_lab_name', 'Name of the lab', ar: 'اسم المعمل', area: 'Selling', where: _sell);
  static const otherLabNameMissing = TextKey('labs.other_lab_name_missing', 'Write the name of the lab that issued the certificate.', ar: 'اكتب اسم المعمل اللي طلّع الشهادة.', area: 'Selling', where: _sell);
  static const chooseLab = TextKey('labs.choose_lab', 'Where will you bring the piece?', ar: 'هتودي القطعة فين؟', area: 'Selling', where: _sell);
  static const chooseBranchHint = TextKey('labs.choose_branch_hint', 'Choose one lab and one of its branches.', ar: 'اختار معمل واحد وفرع واحد منه.', area: 'Selling', where: _sell);
  static const chooseBranchMissing = TextKey('labs.choose_branch_missing', 'Choose a branch to bring the piece to.', ar: 'اختار الفرع اللي هتودي له القطعة.', area: 'Selling', where: _sell);
  static const recommended = TextKey('labs.recommended', 'Recommended', ar: 'موصى به', area: 'Selling', where: _sell);
  static const free = TextKey('labs.free', 'Free', ar: 'مجانًا', area: 'Selling', where: _sell);
  static const none = TextKey('labs.none_open', 'No lab is taking pieces right now. Try again later.', ar: 'مفيش معمل بيستقبل قطع دلوقتي. جرّب تاني بعدين.', area: 'Selling', where: _sell);
  static const certificateCost = TextKey('labs.certificate_cost', 'Certificate cost', ar: 'تكلفة الشهادة', area: 'Selling', where: _sell);
  static const inspectionCost = TextKey('labs.inspection_cost', 'Gold inspection', ar: 'فحص الدهب', area: 'Selling', where: _sell);
  static const certificateNote = TextKey('labs.certificate_note', 'The cost comes out of your money when the piece sells. The lab checks the certificate against the stone at handover.', ar: 'التكلفة بتتخصم من فلوسك لما القطعة تتباع. المعمل بيراجع الشهادة على الحجر عند التسليم.', area: 'Selling', where: _sell);

  static const certFrom = TextKey('labs.cert_from', '{lab} certificate', ar: 'شهادة {lab}', placeholders: ['lab'], area: 'Selling', where: _piece);
  static const labGone = TextKey('labs.lab_gone', 'This lab is not taking pieces right now, so your piece is off the market. Choose another lab to bring it back.', ar: 'المعمل ده مش بيستقبل قطع دلوقتي، فالقطعة مش ظاهرة في السوق. اختار معمل تاني عشان ترجع.', area: 'Selling', where: _piece);
  static const chooseAnother = TextKey('labs.choose_another', 'Choose another lab', ar: 'اختار معمل تاني', area: 'Selling', where: _piece);
  static const newCost = TextKey('labs.new_cost', 'Your piece is at {lab} now.', ar: 'قطعتك دلوقتي في {lab}.', placeholders: ['lab'], area: 'Selling', where: _piece);
  static const notAvailable = TextKey('labs.not_available', 'This lab is not taking pieces right now. Choose another.', ar: 'المعمل ده مش بيستقبل قطع دلوقتي. اختار غيره.', area: 'Selling', where: _piece);
  static const acceptTitle = TextKey('labs.accept_title', 'Accept this request?', ar: 'تقبل الطلب ده؟', area: 'Selling', where: _piece);
  static const acceptBody = TextKey('labs.accept_body', 'Bring the piece to {branch}. Your deadline is counted in working hours there.', ar: 'ودّي القطعة لـ {branch}. المهلة بتتحسب بساعات العمل هناك.', placeholders: ['branch'], area: 'Selling', where: _piece);
  static const acceptYes = TextKey('labs.accept_yes', 'Accept', ar: 'اقبل', area: 'Selling', where: _piece);

  static const all = <TextKey>[
    certificateQuestion,
    anotherLab,
    noCertificate,
    otherLabName,
    otherLabNameMissing,
    chooseLab,
    chooseBranchHint,
    chooseBranchMissing,
    recommended,
    free,
    none,
    certificateCost,
    inspectionCost,
    certificateNote,
    certFrom,
    labGone,
    chooseAnother,
    newCost,
    notAvailable,
    acceptTitle,
    acceptBody,
    acceptYes,
  ];
}
