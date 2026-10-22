import '../text_key.dart';

/// A buy request refused because the buyer owes a step on an order already won
/// (backend `balance_due_first`): the balance, or an answer to a new price.
/// `buy_request.balance_due.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class BuyRequestBalanceKeys {
  static const _area = 'Buying';
  static const _where = 'Piece page';

  static const title = TextKey(
    'buy_request.balance_due.title',
    'Finish your open order first',
    ar: 'خلّص طلبك المفتوح الأول',
    area: _area,
    where: _where,
  );
  static const bodyPay = TextKey(
    'buy_request.balance_due.body_pay',
    'Order {order_ref} is waiting for you to pay the balance. Pay it, then you can ask for another piece.',
    ar: 'الطلب {order_ref} مستنيك تدفع الباقي. ادفعه، وبعدها تقدر تطلب قطعة تانية.',
    placeholders: ['order_ref'],
    area: _area,
    where: _where,
  );
  static const bodyDecide = TextKey(
    'buy_request.balance_due.body_decide',
    'Order {order_ref} is waiting for your answer to a new price. Answer it, then you can ask for another piece.',
    ar: 'الطلب {order_ref} مستني ردّك على السعر الجديد. رُد عليه، وبعدها تقدر تطلب قطعة تانية.',
    placeholders: ['order_ref'],
    area: _area,
    where: _where,
  );
  static const open = TextKey('buy_request.balance_due.open', 'Open the order', ar: 'افتح الطلب', area: _area, where: _where);

  static const all = <TextKey>[title, bodyPay, bodyDecide, open];
}
