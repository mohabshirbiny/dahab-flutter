import '../../models/invoice.dart';
import '../../models/wallet.dart';
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// The wallet from the backend (spec 008): `GET /customer/me/wallet` and
/// `GET /customer/me/wallet/transactions`; top-ups (spec 009): the receiving
/// accounts, receipt upload, notices and cancel; tax invoices and credit notes
/// (spec 016).
///
/// Signed out, or signed in but not verified yet (`verification_required`),
/// the wallet is empty — no money can have moved — and the Wallet screen tells
/// an unverified customer why.
class ApiWalletRepository implements WalletRepository {
  ApiWalletRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  /// Pages read for the history (newest first); older movements are not shown yet.
  static const maxPages = 8;

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  @override
  Future<WalletSummary> summary() async {
    if (!_signedIn) return WalletSummary.empty;
    try {
      final res = await _client.get('/customer/me/wallet', auth: true);
      return WalletSummary.fromJson((res?['data'] as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.code == 'verification_required') return WalletSummary.empty;
      rethrow;
    }
  }

  /// `GET /customer/me/wallet/held` (backend spec 015): each request and order holding money.
  @override
  Future<HeldItems> held() async {
    if (!_signedIn) return HeldItems.empty;
    try {
      final res = await _client.get('/customer/me/wallet/held', auth: true);
      return HeldItems.fromJson((res?['data'] as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.code == 'verification_required') return HeldItems.empty;
      rethrow;
    }
  }

  @override
  Future<List<WalletTxn>> transactions() async {
    if (!_signedIn) return const [];
    final rows = <WalletTxn>[];
    String? cursor;
    try {
      for (var page = 0; page < maxPages; page++) {
        final query = cursor == null ? '?per_page=100' : '?per_page=100&cursor=${Uri.encodeQueryComponent(cursor)}';
        final res = await _client.get('/customer/me/wallet/transactions$query', auth: true);
        for (final row in (res?['data'] as List? ?? const [])) {
          rows.add(WalletTxn.fromJson((row as Map).cast<String, dynamic>()));
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

  /// `GET /customer/me/wallet/topup-methods` (backend spec 009). Trade gate:
  /// throws `verification_required` / `account_suspended` for the screen to explain.
  @override
  Future<TopUpMethods> topUpMethods() async {
    final res = await _client.get('/customer/me/wallet/topup-methods', auth: true);
    return TopUpMethods.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  /// `POST /customer/me/uploads` with `purpose=topup_receipt` (image or PDF).
  @override
  Future<String> uploadReceipt(UploadFile file) async {
    final res = await _client.postMultipart('/customer/me/uploads', fields: {'purpose': 'topup_receipt'}, files: [file], auth: true);
    return (res?['data'] as Map)['upload_token'] as String;
  }

  /// `POST /customer/me/wallet/topups` with an `Idempotency-Key`.
  @override
  Future<TopUp> submitTopUp({required String amount, required int accountId, String? receiptToken, required String idempotencyKey}) async {
    final res = await _client.post(
      '/customer/me/wallet/topups',
      body: {'amount': amount, 'receiving_account_id': accountId, 'receipt_upload_token': ?receiptToken},
      auth: true,
      idempotencyKey: idempotencyKey,
    );
    return TopUp.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  /// `GET /customer/me/wallet/topups` (verified gate: a suspended customer may read).
  @override
  Future<List<TopUp>> topUps() async {
    if (!_signedIn) return const [];
    final rows = <TopUp>[];
    String? cursor;
    try {
      for (var page = 0; page < maxPages; page++) {
        final query = cursor == null ? '?per_page=50' : '?per_page=50&cursor=${Uri.encodeQueryComponent(cursor)}';
        final res = await _client.get('/customer/me/wallet/topups$query', auth: true);
        for (final row in (res?['data'] as List? ?? const [])) {
          rows.add(TopUp.fromJson((row as Map).cast<String, dynamic>()));
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

  /// `POST /customer/me/wallet/topups/{id}/cancel` with an `Idempotency-Key`.
  @override
  Future<TopUp> cancelTopUp(String id, {required String idempotencyKey}) async {
    final res = await _client.post('/customer/me/wallet/topups/${Uri.encodeComponent(id)}/cancel', auth: true, idempotencyKey: idempotencyKey);
    return TopUp.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  /// `GET /customer/me/invoices` (backend spec 016; verified gate, a suspended customer may read).
  @override
  Future<List<CustomerInvoice>> invoices() async {
    if (!_signedIn) return const [];
    final rows = <CustomerInvoice>[];
    String? cursor;
    try {
      for (var page = 0; page < maxPages; page++) {
        final query = cursor == null ? '?per_page=50' : '?per_page=50&cursor=${Uri.encodeQueryComponent(cursor)}';
        final res = await _client.get('/customer/me/invoices$query', auth: true);
        for (final row in (res?['data'] as List? ?? const [])) {
          rows.add(CustomerInvoice.fromJson((row as Map).cast<String, dynamic>()));
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

  /// `GET /customer/me/invoices/{id}`: the lines, Dahab's details and the credit notes.
  @override
  Future<CustomerInvoice> invoice(String id) async {
    final res = await _client.get('/customer/me/invoices/${Uri.encodeComponent(id)}', auth: true);
    return CustomerInvoice.fromJson((res?['data'] as Map).cast<String, dynamic>());
  }

  /// `GET /customer/me/invoices/{id}/pdf` — 409 `document_not_ready` while it is being made.
  @override
  Future<InvoiceFile> invoicePdf(String id, String number) async {
    final file = await _client.getBytes('/customer/me/invoices/${Uri.encodeComponent(id)}/pdf', auth: true);
    return InvoiceFile(filename: '$number.pdf', bytes: file.bytes);
  }

  /// `GET /customer/me/credit-notes/{id}/pdf`.
  @override
  Future<InvoiceFile> creditNotePdf(String id, String number) async {
    final file = await _client.getBytes('/customer/me/credit-notes/${Uri.encodeComponent(id)}/pdf', auth: true);
    return InvoiceFile(filename: '$number.pdf', bytes: file.bytes);
  }
}
