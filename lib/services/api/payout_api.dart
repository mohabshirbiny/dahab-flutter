import '../../models/payout.dart';
import '../../models/reference.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Payout accounts and withdrawals from the backend (spec 013):
/// `/customer/me/payout-accounts*`, `/customer/me/withdrawals*` and the public
/// email-link page `/withdrawal-confirmations/read|confirm`.
///
/// Reads need a verified customer (a suspended one may read); account changes
/// need the trade gate; withdrawals need the verified gate, so a suspended
/// customer can still withdraw what is left and cancel.
class ApiPayoutRepository implements PayoutRepository {
  ApiPayoutRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  static const _accounts = '/customer/me/payout-accounts';
  static const _withdrawals = '/customer/me/withdrawals';

  /// Pages read for the list (newest first).
  static const maxPages = 4;

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  static Map<String, dynamic> _data(Map<String, dynamic>? res) => ((res?['data'] as Map?) ?? const {}).cast<String, dynamic>();

  static String _id(String id) => Uri.encodeComponent(id);

  @override
  Future<PayoutView> accounts() async {
    if (!_signedIn) return PayoutView.empty;
    try {
      return PayoutView.fromJson(_data(await _client.get(_accounts, auth: true)));
    } on ApiException catch (e) {
      if (e.code == 'verification_required') return PayoutView.empty;
      rethrow;
    }
  }

  @override
  Future<LegalDoc> declaration() async => LegalDoc.fromJson(_data(await _client.get('/reference/legal-documents/payout_account_declaration')));

  @override
  Future<PayoutView> add({required String bankName, required String accountName, required String number, required int declarationId, required String idempotencyKey}) async =>
      PayoutView.fromJson(
        _data(
          await _client.post(
            _accounts,
            body: {'bank_name': bankName, 'account_name': accountName, 'account_number_or_iban': number, 'declaration_id': declarationId, 'declaration_accepted': true},
            auth: true,
            idempotencyKey: idempotencyKey,
          ),
        ),
      );

  @override
  Future<(PayoutView, List<String>)> use(String id, {required String idempotencyKey}) async {
    final res = await _client.post('$_accounts/${_id(id)}/use', auth: true, idempotencyKey: idempotencyKey);
    final cancelled = ((res?['meta'] as Map?)?['cancelled_withdrawals'] as List? ?? const []).map((e) => '$e').toList();
    return (PayoutView.fromJson(_data(res)), cancelled);
  }

  @override
  Future<PayoutView> remove(String id, {required String idempotencyKey}) async =>
      PayoutView.fromJson(_data(await _client.post('$_accounts/${_id(id)}/remove', auth: true, idempotencyKey: idempotencyKey)));

  @override
  Future<PayoutView> keep(String id, {required String idempotencyKey}) async =>
      PayoutView.fromJson(_data(await _client.post('$_accounts/${_id(id)}/keep', auth: true, idempotencyKey: idempotencyKey)));

  @override
  Future<WithdrawalConfirmation> requestConfirmation({required String amount, required String accountId, required String idempotencyKey}) async => WithdrawalConfirmation.fromJson(
    _data(await _client.post('$_withdrawals/confirmations', body: {'amount': amount, 'payout_account_id': accountId}, auth: true, idempotencyKey: idempotencyKey)),
  );

  @override
  Future<WithdrawalConfirmation> confirmation(String id) async => WithdrawalConfirmation.fromJson(_data(await _client.get('$_withdrawals/confirmations/${_id(id)}', auth: true)));

  @override
  Future<CustomerWithdrawal> submit({required String confirmationId, required String amount, required String accountId, required String idempotencyKey}) async =>
      CustomerWithdrawal.fromJson(
        _data(
          await _client.post(_withdrawals, body: {'confirmation_id': confirmationId, 'amount': amount, 'payout_account_id': accountId}, auth: true, idempotencyKey: idempotencyKey),
        ),
      );

  @override
  Future<List<CustomerWithdrawal>> withdrawals({String? state}) async {
    if (!_signedIn) return const [];
    final rows = <CustomerWithdrawal>[];
    String? cursor;
    try {
      for (var page = 0; page < maxPages; page++) {
        final query = ['per_page=50', if (state != null) 'state=$state', if (cursor != null) 'cursor=${Uri.encodeQueryComponent(cursor)}'];
        final res = await _client.get('$_withdrawals?${query.join('&')}', auth: true);
        for (final row in (res?['data'] as List? ?? const [])) {
          rows.add(CustomerWithdrawal.fromJson((row as Map).cast<String, dynamic>()));
        }
        cursor = (res?['meta'] as Map?)?['next_cursor'] as String?;
        if (cursor == null) break;
      }
    } on ApiException catch (e) {
      if (e.code == 'verification_required') return const [];
      rethrow;
    }
    return rows;
  }

  @override
  Future<CustomerWithdrawal> cancel(String id, {required String idempotencyKey}) async =>
      CustomerWithdrawal.fromJson(_data(await _client.post('$_withdrawals/${_id(id)}/cancel', auth: true, idempotencyKey: idempotencyKey)));

  @override
  Future<LinkConfirmation> readLink(String token) async => LinkConfirmation.fromJson(_data(await _client.post('/withdrawal-confirmations/read', body: {'token': token})));

  @override
  Future<LinkConfirmation> confirmLink(String token) async => LinkConfirmation.fromJson(_data(await _client.post('/withdrawal-confirmations/confirm', body: {'token': token})));
}
