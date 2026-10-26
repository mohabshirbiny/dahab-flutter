import '../text_key.dart';

/// Putting a piece the seller took down back on the market (backend: settings page and relist,
/// `POST /customer/me/listings/{id}/relist`): the button and its question on My listings and on
/// the piece page, and what a taken-down piece says. `listing.relist.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class ListingRelistKeys {
  static const _area = 'Selling';
  static const _where = 'My listings and the piece page';

  static const button = TextKey('listing.relist.button', 'Put it back on the market', ar: 'رجّعها السوق', area: _area, where: _where);
  static const askTitle = TextKey('listing.relist.ask_title', 'Put this piece back on the market', ar: 'ترجّع القطعة دي السوق؟', area: _area, where: _where);
  static const askBody = TextKey(
    'listing.relist.ask_body',
    'Buyers can see it again at once, at the price it had. It does not go through review again.',
    ar: 'المشترين هيشوفوها تاني على طول، بنفس السعر اللي كان عليها. ومش هتتراجع تاني.',
    area: _area,
    where: _where,
  );
  static const takenDownByYou = TextKey(
    'listing.relist.taken_down_by_you',
    'You took this piece off the market. You can put it back whenever you like.',
    ar: 'إنت شلت القطعة دي من السوق. تقدر ترجّعها وقت ما تحب.',
    area: _area,
    where: _where,
  );
  static const takenDownByDahab = TextKey(
    'listing.relist.taken_down_by_dahab',
    'Dahab took this piece off the market. Only Dahab can put it back: contact customer service.',
    ar: 'دهب شالت القطعة دي من السوق. دهب بس اللي تقدر ترجّعها: كلّم خدمة العملاء.',
    area: _area,
    where: _where,
  );
  static const notRelistable = TextKey(
    'listing.relist.not_relistable',
    'This piece cannot go back on the market. To sell it, list it again.',
    ar: 'القطعة دي مينفعش ترجع السوق. لو عايز تبيعها، اعرضها من الأول.',
    area: _area,
    where: _where,
  );

  static const all = [button, askTitle, askBody, takenDownByYou, takenDownByDahab, notRelistable];
}
