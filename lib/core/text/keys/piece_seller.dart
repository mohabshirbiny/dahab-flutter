import '../text_key.dart';

/// The piece page (seller notes of 2026-10-27): how many sales the piece's seller completed on Dahab
/// (`seller_sales_count` of the market piece; a count, never who), and the video played inside the page.
/// `piece.seller_*`, `piece.video_*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class PieceSellerKeys {
  static const _area = 'Browse';
  static const _where = 'Piece page';

  static const verified = TextKey(
    'piece.seller_verified',
    'Verified seller',
    ar: 'بايع متأكَّد من هويته',
    area: _area,
    where: _where,
  );
  static const salesNone = TextKey(
    'piece.seller_sales_none',
    'New on Dahab, no completed sale yet',
    ar: 'جديد على دهب، لسه مكمّلش أي بيعة',
    area: _area,
    where: _where,
  );
  static const salesOne = TextKey(
    'piece.seller_sales_one',
    'Has completed 1 sale on Dahab',
    ar: 'كمّل بيعة واحدة على دهب',
    area: _area,
    where: _where,
  );
  static const salesMany = TextKey(
    'piece.seller_sales_many',
    'Has completed {count} sales on Dahab',
    ar: 'كمّل {count} بيعات على دهب',
    area: _area,
    where: _where,
    placeholders: ['count'],
  );
  static const videoTap = TextKey(
    'piece.video_tap_to_play',
    'Tap to play the video',
    ar: 'دوس عشان تشغّل الفيديو',
    area: _area,
    where: _where,
  );
  static const videoLoading = TextKey(
    'piece.video_loading',
    'Loading the video…',
    ar: 'بنحمّل الفيديو…',
    area: _area,
    where: _where,
  );
  static const videoFailed = TextKey(
    'piece.video_failed',
    'The video could not be loaded. Tap to try again.',
    ar: 'الفيديو مااتحمّلش. دوس وجرّب تاني.',
    area: _area,
    where: _where,
  );
  static const videoClose = TextKey('piece.video_close', 'Close', ar: 'اقفل', area: _area, where: _where);

  static const all = [verified, salesNone, salesOne, salesMany, videoTap, videoLoading, videoFailed, videoClose];
}
