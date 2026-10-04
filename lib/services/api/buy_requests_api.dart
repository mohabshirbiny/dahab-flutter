import '../../models/buy_request.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Buy requests from the backend (spec 011). Sending needs a verified,
/// non-suspended customer; reading and leaving a verified one (a suspended
/// buyer may leave). Every write carries an idempotency key: reuse it when
/// retrying the same submission, so the backend replays the first answer and
/// never holds a deposit twice.
class ApiBuyRequestsRepository implements BuyRequestsRepository {
  ApiBuyRequestsRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  static const _base = '/customer/me/buy-requests';

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  @override
  Future<DepositTerms> depositTerms() async {
    final d = ((await _client.get('/reference/legal-documents/deposit_agreement'))?['data'] as Map).cast<String, dynamic>();
    return DepositTerms(id: (d['id'] as num).toInt(), bodyEn: '${d['body_en'] ?? ''}', bodyAr: '${d['body_ar'] ?? ''}');
  }

  @override
  Future<BuyRequest> send({required String listingId, required String confirmedPrice, required int termsId, required String idempotencyKey}) async => _one(
    await _client.post(_base, body: {'listing_id': listingId, 'confirm_locked_price': confirmedPrice, 'deposit_legal_doc_id': termsId}, auth: true, idempotencyKey: idempotencyKey),
  );

  @override
  Future<List<BuyRequest>> mine({String? listingId, String? state}) async {
    if (!_signedIn) return const [];
    final query = <String>['per_page=100', if (listingId != null) 'listing_id=${Uri.encodeQueryComponent(listingId)}', if (state != null) 'state=$state'];
    try {
      final res = await _client.get('$_base?${query.join('&')}', auth: true);
      return [for (final row in (res?['data'] as List? ?? const [])) BuyRequest.fromJson((row as Map).cast<String, dynamic>())];
    } on ApiException catch (e) {
      // Not verified yet: no request can exist.
      if (e.code == 'verification_required') return const [];
      rethrow;
    }
  }

  @override
  Future<BuyRequest> leave(String id, {required bool notifyWhenFree, required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/withdraw', body: {'notify_when_free': notifyWhenFree}, auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<SellerQueue> queue(String listingId) async {
    final res = await _client.get('/customer/me/listings/${Uri.encodeComponent(listingId)}/buy-requests', auth: true);
    return SellerQueue(
      items: [for (final row in (res?['data'] as List? ?? const [])) SellerQueueItem.fromJson((row as Map).cast<String, dynamic>())],
      youWouldReceive: (res?['meta'] as Map?)?['you_would_receive'] as String?,
    );
  }

  @override
  Future<OrderSummary> accept(String listingId, String requestId, int branchId, {required String idempotencyKey}) async {
    final res = await _client.post(
      '/customer/me/listings/${Uri.encodeComponent(listingId)}/accept',
      body: {'buy_request_id': requestId, 'branch_id': branchId},
      auth: true,
      idempotencyKey: idempotencyKey,
    );
    return OrderSummary.fromJson((res?['data'] as Map?)?['order'])!;
  }

  @override
  Future<void> decline(String listingId, String requestId, {required String idempotencyKey}) async {
    await _client.post('/customer/me/listings/${Uri.encodeComponent(listingId)}/decline', body: {'buy_request_id': requestId}, auth: true, idempotencyKey: idempotencyKey);
  }

  BuyRequest _one(Map<String, dynamic>? res) => BuyRequest.fromJson((res?['data'] as Map).cast<String, dynamic>());
}

/// The figures of a 409 `insufficient_funds` on a buy request, or null.
DepositShortfall? shortfallOf(ApiException e) {
  final d = (e.extra['details'] as Map?)?.cast<String, dynamic>();
  if (e.code != 'insufficient_funds' || d == null) return null;
  return DepositShortfall(depositAmount: '${d['deposit_amount']}', available: '${d['available']}', shortfall: '${d['shortfall']}');
}

/// The fresh price of a 409 `price_moved`, or null.
String? movedPriceOf(ApiException e) {
  if (e.code != 'price_moved') return null;
  final price = (e.extra['details'] as Map?)?['current_price'];
  return price is String ? price : null;
}
