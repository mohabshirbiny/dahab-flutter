import '../text_key.dart';

/// The Help screen's own words (backend spec 019 US5). The questions and answers themselves
/// are not keys here: staff write them in the Dashboard and the app shows what the bundle
/// carries. The Arabic is AR-DRAFT (spec Appendix B) until the owner approves it.
abstract final class AccountHelpKeys {
  static const _area = 'Help';
  static const _where = 'Help screen';

  static const empty = TextKey(
    'help.empty',
    'Nothing here yet. Contact us if you have a question.',
    ar: 'لسه مفيش أسئلة هنا. كلمنا لو عندك سؤال.',
    area: _area,
    where: _where,
  );

  static const all = <TextKey>[empty];
}
