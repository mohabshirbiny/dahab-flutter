import '../../models/account.dart';
import '../../models/piece.dart';
import '../../models/reference.dart';
import '../mock_repositories.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// The customer's own account from the backend (spec 017): `/customer/me/phone-change*`,
/// `/email-change`, `/password`, `/sessions*`, `/notifications*`, `/saved-pieces*`,
/// `/account/close*`, `/listing-reports`, the public email-link page
/// `/contact-changes/email/read|confirm` and `/reference/legal-documents|support-contacts`.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._client, this._tokens, {AccountRepository? fallback}) : _fallback = fallback ?? MockAccountRepository();

  final ApiClient _client;
  final TokenStore _tokens;
  final AccountRepository _fallback;

  static const _me = '/customer/me';

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  static Map<String, dynamic> _data(Map<String, dynamic>? res) => ((res?['data'] as Map?) ?? const {}).cast<String, dynamic>();

  static List<Map<String, dynamic>> _rows(Map<String, dynamic>? res) => [for (final r in (res?['data'] as List? ?? const [])) (r as Map).cast<String, dynamic>()];

  static String _id(String id) => Uri.encodeComponent(id);

  @override
  Future<UserProfile> profile() => _fallback.profile();

  @override
  Future<PhoneChallenge> requestPhoneChange(String phone, {required String idempotencyKey}) async {
    final d = _data(await _client.post('$_me/phone-change', body: {'phone': phone}, auth: true, idempotencyKey: idempotencyKey));
    return PhoneChallenge(id: '${d['challenge_id']}', phoneMasked: '${d['phone_masked'] ?? ''}', expiresAt: DateTime.tryParse('${d['expires_at'] ?? ''}'));
  }

  @override
  Future<DateTime?> confirmPhoneChange(String challengeId, String code, {required String idempotencyKey}) async {
    final d = _data(await _client.post('$_me/phone-change/${_id(challengeId)}/confirm', body: {'code': code}, auth: true, idempotencyKey: idempotencyKey));
    return DateTime.tryParse('${d['pause_until'] ?? ''}');
  }

  @override
  Future<String> requestEmailChange(String email, {required String idempotencyKey}) async =>
      '${_data(await _client.post('$_me/email-change', body: {'email': email}, auth: true, idempotencyKey: idempotencyKey))['email_masked'] ?? ''}';

  @override
  Future<String> readEmailLink(String token) async => '${_data(await _client.post('/contact-changes/email/read', body: {'token': token}))['email_masked'] ?? ''}';

  @override
  Future<DateTime?> confirmEmailLink(String token) async =>
      DateTime.tryParse('${_data(await _client.post('/contact-changes/email/confirm', body: {'token': token}))['pause_until'] ?? ''}');

  @override
  Future<int> changePassword({required String current, required String next, required String idempotencyKey}) async {
    final d = _data(
      await _client.post('$_me/password', body: {'current_password': current, 'password': next, 'password_confirmation': next}, auth: true, idempotencyKey: idempotencyKey),
    );
    return (d['signed_out_sessions'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<AccountSession>> sessions() async {
    if (!_signedIn) return const [];
    return [for (final r in _rows(await _client.get('$_me/sessions', auth: true))) AccountSession.fromJson(r)];
  }

  @override
  Future<void> signOutSession(String id, {required String idempotencyKey}) async {
    await _client.post('$_me/sessions/${_id(id)}/sign-out', auth: true, idempotencyKey: idempotencyKey);
  }

  @override
  Future<InboxPage> inbox({String? cursor}) async {
    if (!_signedIn) return const InboxPage(items: [], nextCursor: null, unread: 0);
    final query = cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final res = await _client.get('$_me/notifications$query', auth: true);
    final meta = ((res?['meta'] as Map?) ?? const {}).cast<String, dynamic>();
    return InboxPage(items: [for (final r in _rows(res)) InboxItem.fromJson(r)], nextCursor: meta['next_cursor'] as String?, unread: (meta['unread_count'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<int> unreadCount() async {
    if (!_signedIn) return 0;
    return (_data(await _client.get('$_me/notifications/unread-count', auth: true))['unread_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id, {required String idempotencyKey}) async {
    await _client.post('$_me/notifications/${_id(id)}/read', auth: true, idempotencyKey: idempotencyKey);
  }

  @override
  Future<void> markAllRead({required String idempotencyKey}) async {
    await _client.post('$_me/notifications/read-all', auth: true, idempotencyKey: idempotencyKey);
  }

  @override
  Future<List<SavedPiece>> saved({String? listingId}) async {
    if (!_signedIn) return const [];
    final query = listingId == null ? '' : '?listing_id=${Uri.encodeQueryComponent(listingId)}';
    return [for (final r in _rows(await _client.get('$_me/saved-pieces$query', auth: true))) SavedPiece.fromJson(r)];
  }

  @override
  Future<void> save(String listingId, {required String idempotencyKey}) async {
    await _client.post('$_me/saved-pieces', body: {'listing_id': listingId}, auth: true, idempotencyKey: idempotencyKey);
  }

  @override
  Future<void> unsave(String listingId) async {
    await _client.delete('$_me/saved-pieces/${_id(listingId)}', auth: true);
  }

  @override
  Future<List<CloseBlocker>> closeCheck() async {
    final d = _data(await _client.get('$_me/account/close-check', auth: true));
    return [for (final b in (d['blockers'] as List? ?? const [])) CloseBlocker('${(b as Map)['code']}', ((b['count'] as num?) ?? 1).toInt())];
  }

  @override
  Future<void> close({required String reason, String? note, required String idempotencyKey}) async {
    await _client.post('$_me/account/close', body: {'reason': reason, 'note': ?note}, auth: true, idempotencyKey: idempotencyKey);
  }

  @override
  Future<String> report({required String listingId, required String reason, String? note, required String idempotencyKey}) async =>
      '${_data(await _client.post('$_me/listing-reports', body: {'listing_id': listingId, 'reason': reason, 'note': ?note}, auth: true, idempotencyKey: idempotencyKey))['reference'] ?? ''}';

  @override
  Future<List<LegalEntry>> legalDocuments() async => [
    for (final r in _rows(await _client.get('/reference/legal-documents'))) LegalEntry(code: '${r['code']}', published: r['published'] == true),
  ];

  @override
  Future<LegalDoc> legalDocument(String code) async => LegalDoc.fromJson(_data(await _client.get('/reference/legal-documents/${_id(code)}')));

  @override
  Future<SupportContacts> supportContacts() async => SupportContacts.fromJson(_data(await _client.get('/reference/support-contacts')));
}
