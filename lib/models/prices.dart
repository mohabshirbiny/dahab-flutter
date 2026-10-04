import '../services/pricing.dart';

/// Today's prices from `GET /reference/gold-prices` (backend spec 015): per
/// enabled karat what sellers get and what buyers pay per gram, from the
/// backend's calculator. Parsed for display only — the app never prices.
class GoldPrices {
  const GoldPrices({required this.karats, required this.feedState, this.priceAt});

  factory GoldPrices.fromJson(Map<String, dynamic> j) => GoldPrices(
    karats: {
      for (final k in (j['karats'] as List? ?? const [])) ((k as Map)['code'] as num).toInt(): KaratPrice(sellersGet: _num(k['sellers_get']), buyersPay: _num(k['buyers_pay'])),
    },
    feedState: '${j['feed_state'] ?? ''}',
    priceAt: DateTime.tryParse('${j['price_at'] ?? ''}')?.toLocal(),
  );

  final Map<int, KaratPrice> karats;

  /// `live`, `manual` or `stale`.
  final String feedState;
  final DateTime? priceAt;
}

class KaratPrice {
  const KaratPrice({required this.sellersGet, required this.buyersPay});

  final num sellersGet;
  final num buyersPay;
}

/// What a quote is asked for: the sell form's piece, or the home calculator's.
class QuoteParams {
  const QuoteParams({required this.type, this.karat, this.weight = 0, this.makingPerGram = 0, this.askingPrice = 0});

  final SellType type;
  final int? karat;
  final double weight;
  final double makingPerGram;
  final double askingPrice;

  String get category => switch (type) {
    SellType.gold => 'gold',
    SellType.diamond => 'diamond',
    SellType.mixed => 'gold_with_diamond',
  };

  /// The query string of `GET /reference/quote`.
  String get query {
    final q = <String, String>{'category': category};
    if (type != SellType.diamond) {
      q['karat'] = '$karat';
      q['weight_g'] = weight.toStringAsFixed(3);
    }
    if (type == SellType.gold) q['making_per_g'] = makingPerGram.toStringAsFixed(2);
    if (type != SellType.gold) q['asking_price'] = askingPrice.toStringAsFixed(2);
    return q.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  }

  /// A request the backend would refuse (no weight, no asking price): nothing to ask.
  bool get askable => switch (type) {
    SellType.gold => karat != null && weight > 0,
    SellType.mixed => karat != null && weight > 0 && askingPrice > 0,
    SellType.diamond => askingPrice > 0,
  };

  @override
  bool operator ==(Object other) => other is QuoteParams && other.query == query;

  @override
  int get hashCode => query.hashCode;
}

/// "What will I get" from `GET /reference/quote` (backend spec 015): every
/// figure is the backend's; [commission] here includes VAT, so the rows add
/// up to [SellQuote.net].
SellQuote sellQuoteFromJson(Map<String, dynamic> j) {
  final category = '${j['category'] ?? 'gold'}';
  final asking = _num(j['asking_price']).toDouble();
  final rate = _num(j['commission_rate']);
  final minimum = j['minimum_applied'] == true;
  final gold = category == 'gold';
  return SellQuote(
    goldValue: _num(j['gold_value']).toDouble(),
    making: _num(j['making_back']).toDouble(),
    stone: category == 'diamond' ? asking : 0,
    ask: category == 'gold_with_diamond' ? asking : 0,
    commission: (_num(j['commission']) + _num(j['vat'])).toDouble(),
    promoSaving: 0,
    net: _num(j['payout']).toDouble(),
    jewellerPays: _num(j['gold_value']).toDouble(),
    commissionNote: minimum ? '(minimum)' : '(${rate.round()}% of ${gold ? 'the making charge' : 'the value you add'})',
  );
}

num _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
