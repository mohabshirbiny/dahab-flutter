import '../../models/listing.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// The seller's own listings from the backend (spec 010):
/// `/customer/me/listings*` and the listing purposes of
/// `POST /customer/me/uploads`. Reads need a verified customer (a suspended
/// one may read); every write needs a verified, non-suspended customer and an
/// `Idempotency-Key`. The screens explain the refusals
/// (`verification_required`, `account_suspended`, the listing codes).
class ApiListingsRepository implements ListingsRepository {
  ApiListingsRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  static const _base = '/customer/me/listings';

  /// Pages read for My listings (50 each).
  static const maxPages = 6;

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  @override
  Future<List<Listing>> mine() async {
    if (!_signedIn) return const [];
    final rows = <Listing>[];
    String? cursor;
    try {
      for (var page = 0; page < maxPages; page++) {
        final query = cursor == null ? '?per_page=50' : '?per_page=50&cursor=${Uri.encodeQueryComponent(cursor)}';
        final res = await _client.get('$_base$query', auth: true);
        for (final row in (res?['data'] as List? ?? const [])) {
          rows.add(Listing.fromJson((row as Map).cast<String, dynamic>()));
        }
        cursor = (res?['meta'] as Map?)?['next_cursor'] as String?;
        if (cursor == null) break;
      }
    } on ApiException catch (e) {
      // Not verified yet: no listing can exist.
      if (e.code == 'verification_required') return const [];
      rethrow;
    }
    return rows;
  }

  @override
  Future<Listing> show(String id) async => _one(await _client.get('$_base/${Uri.encodeComponent(id)}', auth: true));

  @override
  Future<String> uploadMedia(String purpose, UploadFile file) async {
    final res = await _client.postMultipart('/customer/me/uploads', fields: {'purpose': purpose}, files: [file], auth: true);
    return (res?['data'] as Map)['upload_token'] as String;
  }

  @override
  Future<Listing> create(Map<String, dynamic> body, {required String idempotencyKey}) async =>
      _one(await _client.post(_base, body: body, auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<Listing> update(String id, Map<String, dynamic> body, {required String idempotencyKey}) async =>
      _one(await _client.patch('$_base/${Uri.encodeComponent(id)}', body: body, auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<Listing> submit(String id, {required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/submit', auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<Listing> withdraw(String id, {required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/withdraw', auth: true, idempotencyKey: idempotencyKey));

  Listing _one(Map<String, dynamic>? res) => Listing.fromJson((res?['data'] as Map).cast<String, dynamic>());
}
