import '../text_key.dart';

/// The acceptance screen for the live terms and privacy (backend spec 019, FR-025): shown
/// before anything else to a customer who has accepted nothing yet, and again when a material
/// version is published. The Arabic is AR-DRAFT (spec Appendix B) until the owner approves it;
/// staff can change both languages from App text.
abstract final class AccountLegalKeys {
  static const _area = 'Account';
  static const _where = 'Accept the terms screen, before anything else';

  static const firstTitle = TextKey(
    'legal.accept.first_title',
    'Please accept our terms',
    ar: 'من فضلك وافق على الشروط بتاعتنا',
    area: _area,
    where: _where,
  );
  static const materialTitle = TextKey(
    'legal.accept.material_title',
    'We updated our terms',
    ar: 'حدّثنا الشروط بتاعتنا',
    area: _area,
    where: _where,
  );
  static const body = TextKey(
    'legal.accept.body',
    'Please read and accept the new version to carry on.',
    ar: 'من فضلك اقرا النسخة الجديدة ووافق عليها عشان تكمّل.',
    area: _area,
    where: _where,
  );
  static const version = TextKey('legal.accept.version', 'Version {version}', ar: 'النسخة {version}', placeholders: ['version'], area: _area, where: _where);
  static const accept = TextKey('legal.accept.accept_button', 'I accept', ar: 'موافق', area: _area, where: _where);
  static const loadError = TextKey(
    'legal.accept.load_error',
    'The document could not be loaded. Check your connection and try again.',
    ar: 'مقدرناش نحمّل المستند. اتأكد من الاتصال وحاول تاني.',
    area: _area,
    where: _where,
  );
  static const retry = TextKey('legal.accept.retry', 'Try again', ar: 'حاول تاني', area: _area, where: _where);
  static const signOut = TextKey('legal.accept.sign_out', 'Sign out', ar: 'تسجيل خروج', area: _area, where: _where);

  static const all = <TextKey>[firstTitle, materialTitle, body, version, accept, loadError, retry, signOut];
}
