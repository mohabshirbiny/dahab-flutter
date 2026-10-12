import '../../models/listing.dart';
import '../../models/prices.dart' show QuoteParams;
import '../../models/promo.dart';
import '../../models/referral.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Codes on the sell form (backend spec 023): `POST /customer/me/commission-preview` (stateless, ten
/// a minute) and `PUT|DELETE /customer/me/listings/{id}/promo`. Both need a verified, non-suspended
/// customer; the writes carry an `Idempotency-Key`.
class ApiPromoRepository implements PromoRepository {
  ApiPromoRepository(this._client);

  final ApiClient _client;

  @override
  Future<PromoPreview> preview(QuoteParams piece, {String? code}) async {
    final body = <String, dynamic>{
      'category': piece.category,
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
    };
    if (piece.category != 'diamond') {
      body['karat'] = piece.karat;
      body['weight_g'] = piece.weight.toStringAsFixed(3);
    }
    if (piece.category == 'gold') body['making_charge_per_g'] = piece.makingPerGram.toStringAsFixed(2);
    if (piece.category != 'gold') body['asking_price'] = piece.askingPrice.toStringAsFixed(2);

    final res = await _client.post('/customer/me/commission-preview', body: body, auth: true);
    return PromoPreview.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  @override
  Future<Listing> apply(String listingId, String code, {required String idempotencyKey}) async {
    final res = await _client.put('/customer/me/listings/${Uri.encodeComponent(listingId)}/promo', body: {'code': code}, auth: true, idempotencyKey: idempotencyKey);
    return Listing.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  @override
  Future<Listing> remove(String listingId, {required String idempotencyKey}) async {
    final res = await _client.delete('/customer/me/listings/${Uri.encodeComponent(listingId)}/promo', auth: true, idempotencyKey: idempotencyKey);
    return Listing.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }
}

/// *Invite a friend* (backend spec 023): `GET /customer/me/referral`, `POST /customer/me/referral/shares`.
class ApiReferralRepository implements ReferralRepository {
  ApiReferralRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  @override
  Future<ReferralSummary> summary() async {
    if (!_signedIn) return ReferralSummary.fromJson(const {'enabled': false});
    final res = await _client.get('/customer/me/referral', auth: true);
    return ReferralSummary.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  @override
  Future<int> share({required String idempotencyKey}) async {
    final res = await _client.post('/customer/me/referral/shares', auth: true, idempotencyKey: idempotencyKey);
    return ((res?['data'] as Map)['invites_sent'] as num?)?.toInt() ?? 0;
  }
}
