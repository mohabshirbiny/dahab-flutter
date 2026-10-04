import '../../models/piece.dart';
import '../../models/reference.dart';
import '../mock_repositories.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// The public market from the backend (spec 010): `GET /market/listings`
/// and `GET /market/listings/{id}`. No account is needed; when the customer
/// is signed in the token is sent so the backend can mark their own pieces
/// (`is_mine`) — the market never says who a seller is.
///
/// Saved pieces have no backend route yet, so they still come from the mock,
/// and a mock piece id (not a UUID) opens the mock detail.
class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._client, this._tokens, {CatalogRepository? fallback}) : _fallback = fallback ?? MockCatalogRepository();

  final ApiClient _client;
  final TokenStore _tokens;
  final CatalogRepository _fallback;

  /// Pages read for Browse (100 pieces each). Search and the chips then work
  /// on the device, over what was loaded: the market API has no text search.
  static const maxPages = 3;

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  @override
  Future<List<Piece>> pieces() async {
    final rows = <Piece>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final query = cursor == null ? '?per_page=100' : '?per_page=100&cursor=${Uri.encodeQueryComponent(cursor)}';
      final res = await _get('/market/listings$query');
      for (final row in (res?['data'] as List? ?? const [])) {
        rows.add(Piece.fromMarketJson((row as Map).cast<String, dynamic>()));
      }
      cursor = (res?['meta'] as Map?)?['next_cursor'] as String?;
      if (cursor == null) break;
    }
    return rows;
  }

  @override
  Future<PieceDetail> detail(String id) async {
    if (!_uuid.hasMatch(id)) return _fallback.detail(id);
    final res = await _get('/market/listings/${Uri.encodeComponent(id)}');
    return PieceDetail.fromMarketJson((res?['data'] as Map).cast<String, dynamic>());
  }

  @override
  Future<List<Piece>> saved() => _fallback.saved();

  /// The token is optional on the market: a session that has just ended must
  /// not hide the market, so a refused token falls back to an anonymous read.
  Future<Map<String, dynamic>?> _get(String path) async {
    if (!_signedIn) return _client.get(path);
    try {
      return await _client.get(path, auth: true);
    } on ApiException catch (e) {
      if (e.status == 401) return _client.get(path);
      rethrow;
    }
  }
}

/// `GET /reference/*` (backend spec 010): karats, piece types, branches and
/// the ownership declaration. Read once and kept: it changes rarely, and a
/// stale value is refused by the backend with a clear code.
class ApiReferenceRepository implements ReferenceRepository {
  ApiReferenceRepository(this._client);

  final ApiClient _client;
  Future<SellReference>? _cached;

  @override
  Future<SellReference> sellReference() {
    return _cached ??= _load().catchError((Object e) {
      _cached = null;
      throw e;
    });
  }

  /// Forget the cached copy (after the backend said the declaration changed).
  void refresh() => _cached = null;

  Future<SellReference> _load() async {
    final results = await Future.wait([
      _client.get('/reference/karats'),
      _client.get('/reference/piece-types'),
      _client.get('/reference/branches'),
      _client.get('/reference/legal-documents/ownership_declaration'),
    ]);
    List<Map<String, dynamic>> rows(Map<String, dynamic>? res) => [for (final r in (res?['data'] as List? ?? const [])) (r as Map).cast<String, dynamic>()];

    return SellReference(
      karats: [for (final k in rows(results[0])) (k['code'] as num).toInt()],
      pieceTypes: [for (final t in rows(results[1])) PieceTypeRef.fromJson(t)],
      branches: [for (final b in rows(results[2])) BranchRef.fromJson(b)],
      declaration: LegalDoc.fromJson((results[3]?['data'] as Map).cast<String, dynamic>()),
    );
  }
}
