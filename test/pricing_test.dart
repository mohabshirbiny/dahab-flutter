import 'package:dahab_app/models/prices.dart';
import 'package:dahab_app/services/pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pricing matches the prototype', () {
    test('home calculator default: 21K, 8 g, 300/g', () {
      final q = Pricing.gold(rate: 6951, weight: 8, makingPerGram: 300);
      expect(q.goldValue, 55608);
      expect(q.making, 2400);
      expect(q.commission, 480); // 20% of 2,400
      expect(q.net, 57528); // "You would have received 57,528 EGP"
      expect(q.extra, 1920);
    });

    test('commission never below 200 EGP, never above the making charge', () {
      expect(Pricing.commission(500, 0.2), 200);
      expect(Pricing.commission(150, 0.2), 150);
      expect(Pricing.commission(0, 0.2), 0);
    });


    test('diamond suggestion for 0.7ct VS very good', () {
      expect(Pricing.suggestedStone(0.7, 1, 1).round(), 33381);
    });

    test('mixed piece: commission on value above gold', () {
      final q = Pricing.sell(type: SellType.mixed, rate: 6951, weight: 8, makingPerGram: 0, stoneAsk: 0, totalAsk: 90000);
      expect(q.goldValue, 55608);
      expect(q.commission, closeTo((90000 - 55608) * 0.05, 0.01));
    });
  });

  // Backend package C: the commission rate includes VAT. The seller pays exactly the rate.
  group('VAT-inclusive commission', () {
    test('the §3.3 ring: 600 VAT included leaves the seller the value less 600', () {
      final q = sellQuoteFromJson({
        'category': 'gold',
        'gold_value': '52368.7500',
        'making_back': '3000.0000',
        'commission': '526.3158',
        'vat': '73.6842',
        'payout': '54768.7500',
        'commission_rate': '20.0000',
        'minimum_applied': false,
      });
      expect(q.commission, closeTo(600, 0.00001));
      expect(q.goldValue + q.making - q.commission, closeTo(q.net, 0.00001));
    });

    test('the app estimate charges the rate itself, with no VAT on top', () {
      final q = Pricing.gold(rate: 5237, weight: 10, makingPerGram: 300);
      expect(q.commission, 600);
      expect(q.net, 52370 + 3000 - 600);
    });
  });
}
