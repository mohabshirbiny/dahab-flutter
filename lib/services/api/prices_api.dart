import '../../models/prices.dart';
import '../pricing.dart';
import 'api_client.dart';

/// Today's prices and the seller's estimate (backend spec 015): public,
/// unauthenticated reads. `price_unavailable` (409) when no price can be used.
class PricesApi {
  PricesApi(this._client);

  final ApiClient _client;

  Future<GoldPrices> goldPrices() async {
    final res = await _client.get('/reference/gold-prices');
    return GoldPrices.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  Future<SellQuote> quote(QuoteParams params) async {
    final res = await _client.get('/reference/quote?${params.query}');
    return sellQuoteFromJson((res?['data'] as Map).cast<String, dynamic>());
  }
}
