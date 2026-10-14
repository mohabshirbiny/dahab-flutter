import '../text_key.dart';

/// The wallet statement as a PDF made by the backend (wallet statement PDF, items 10–11): the
/// period choice under *Statement* on the Wallet screen, and the line that says the list shows
/// only the latest movements. `wallet.statement.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class WalletStatementKeys {
  static const _area = 'Wallet';
  static const _where = 'Wallet screen, Statement';

  static const period = TextKey('wallet.statement.period', 'Period', ar: 'الفترة', area: _area, where: _where);
  static const last30 = TextKey('wallet.statement.last_30', 'Last 30 days', ar: 'آخر 30 يوم', area: _area, where: _where);
  static const last90 = TextKey('wallet.statement.last_90', 'Last 90 days', ar: 'آخر 90 يوم', area: _area, where: _where);
  static const lastYear = TextKey('wallet.statement.last_year', 'Last 12 months', ar: 'آخر 12 شهر', area: _area, where: _where);
  static const downloadPdf = TextKey('wallet.statement.download_pdf', 'Download PDF', ar: 'نزّل PDF', area: _area, where: _where);
  static const note = TextKey(
    'wallet.statement.note',
    'A PDF with your name, every movement of the period and your balances at the start and the end.',
    ar: 'ملف PDF فيه اسمك وكل حركة في الفترة ورصيدك في أولها وآخرها.',
    area: _area,
    where: _where,
  );
  static const failed = TextKey(
    'wallet.statement.failed',
    'The statement could not be made. Try again in a moment.',
    ar: 'ماقدرناش نعمل الكشف. جرّب تاني بعد شوية.',
    area: _area,
    where: _where,
  );
  static const notVerified = TextKey(
    'wallet.statement.not_verified',
    'Your statement is ready once your ID is verified.',
    ar: 'الكشف بيبقى جاهز أول ما بطاقتك تتأكد.',
    area: _area,
    where: _where,
  );
  static const showingLatest = TextKey(
    'wallet.statement.showing_latest',
    'Showing the latest {count} movements. Download the statement to see older ones.',
    ar: 'معروض آخر {count} حركة. نزّل الكشف عشان تشوف الأقدم.',
    placeholders: ['count'],
    area: _area,
    where: _where,
  );

  static const all = <TextKey>[period, last30, last90, lastYear, downloadPdf, note, failed, notVerified, showingLatest];
}
