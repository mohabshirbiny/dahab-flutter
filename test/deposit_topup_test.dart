import 'package:dahab_app/models/buy_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggests the deposit plus 1% of the price, less the wallet, in whole pounds', () {
    const s = DepositShortfall(depositAmount: '20000.0000', available: '0.0000', shortfall: '20000.0000', price: '100000.00');
    expect(s.suggested, '21000');

    final short = const DepositShortfall(depositAmount: '20000.0000', available: '19500.0000', shortfall: '500.0000').withPrice('100000.40');
    expect(short.suggested, '1501');
  });

  test('falls back to the shortfall without a price', () {
    const s = DepositShortfall(depositAmount: '20000.0000', available: '5000.0000', shortfall: '15000.0000');
    expect(s.suggested, '15000.0000');
  });
}
