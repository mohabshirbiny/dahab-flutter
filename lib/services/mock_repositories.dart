import '../models/invoice.dart';
import '../models/buy_request.dart';
import '../models/dispute.dart';
import '../models/reference.dart';
import '../mock/mock_account.dart';
import '../mock/mock_orders.dart';
import '../mock/mock_pieces.dart';
import '../mock/mock_wallet.dart';
import '../models/account.dart';
import '../models/order.dart';
import '../models/piece.dart';
import '../models/wallet.dart';
import 'api/api_client.dart' show UploadFile;
import 'media_picker.dart' show MediaKind;
import 'repositories.dart';

/// Simulated network latency so loading states are visible.
Future<T> _later<T>(T value, [int ms = 350]) => Future.delayed(Duration(milliseconds: ms), () => value);

class MockCatalogRepository implements CatalogRepository {
  @override
  Future<List<Piece>> pieces() => _later(mockPieces);

  @override
  Future<PieceDetail> detail(String id) => _later(mockDetailFor(id), 200);
}

/// No buy requests without the backend: empty lines and refusals.
class MockBuyRequestsRepository implements BuyRequestsRepository {
  @override
  Future<DepositTerms> depositTerms() async => const DepositTerms(id: 0, bodyEn: '', bodyAr: '');

  @override
  Future<BuyRequest> send({required String listingId, required String confirmedPrice, required int termsId, required String idempotencyKey}) =>
      throw UnsupportedError('No buy requests without the backend.');

  @override
  Future<List<BuyRequest>> mine({String? listingId, String? state}) async => const [];

  @override
  Future<BuyRequest> leave(String id, {required bool notifyWhenFree, required String idempotencyKey}) => throw UnsupportedError('No buy requests without the backend.');

  @override
  Future<SellerQueue> queue(String listingId) async => const SellerQueue(items: [], youWouldReceive: null);

  @override
  Future<OrderSummary> accept(String listingId, String requestId, int branchId, {required String idempotencyKey}) => throw UnsupportedError('No buy requests without the backend.');

  @override
  Future<void> decline(String listingId, String requestId, {required String idempotencyKey}) async {}
}

/// The prototype's cards, with no orders behind them (the app uses the API, spec 012).
class MockOrdersRepository implements OrdersRepository {
  @override
  Future<List<OrderCardData>> orders() => _later(mockOrders);

  @override
  Future<List<CustomerOrder>> list() async => const [];

  @override
  Future<CustomerOrder> show(String id) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> cancel(String id, {required String idempotencyKey}) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> decide(String id, {required bool accept, required String inspectionId, required String idempotencyKey}) =>
      throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> payBalance(String id, {required String idempotencyKey}) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> relist(String id, {required String idempotencyKey}) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<String> upload(MediaKind kind, UploadFile file) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerDispute> openDispute(String id, {required String reason, required String detail, List<String> photoTokens = const [], required String idempotencyKey}) =>
      throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> requestMoreTime(String id, {required String reason, required String detail, required String idempotencyKey}) =>
      throw UnsupportedError('No orders without the backend.');

  @override
  Future<LegalDoc> proxyAuthorisation() => throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> nameProxy(
    String id, {
    required String name,
    required String phone,
    required String idToken,
    required int authorisationId,
    required String idempotencyKey,
  }) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> removeProxy(String id, {required String idempotencyKey}) => throw UnsupportedError('No orders without the backend.');

  @override
  Future<FreeRelisted> freeRelist(String id, {String? makingChargePerG, String? askingPrice, String? description, required int ownershipDocId, required String idempotencyKey}) =>
      throw UnsupportedError('No orders without the backend.');

  @override
  Future<CustomerOrder> rate(String id, {required int stars, String? note, required String idempotencyKey}) => throw UnsupportedError('No orders without the backend.');
}

class MockWalletRepository implements WalletRepository {
  @override
  Future<WalletSummary> summary() => _later(mockWalletSummary, 150);

  @override
  Future<List<WalletTxn>> transactions() => _later(mockTxns);

  @override
  Future<HeldItems> held() => _later(HeldItems.empty);

  @override
  Future<TopUpMethods> topUpMethods() => _later(mockTopUpMethods, 0);

  /// Notices filed in this session (the prototype has no top-up history).
  final List<TopUp> _topUps = [];
  int _next = 128;

  @override
  Future<String> uploadReceipt(UploadFile file) => _later('mock-receipt-${file.filename}', 200);

  @override
  Future<TopUp> submitTopUp({required String amount, required int accountId, String? receiptToken, required String idempotencyKey}) {
    final account = mockTopUpMethods.methods.expand((m) => m.$2).firstWhere((a) => a.id == accountId);
    final topUp = TopUp(
      id: 'mock-$_next',
      number: 'TOP-${_next++}',
      method: account.method,
      reference: mockTopUpMethods.reference,
      status: TopUpStatus.pending,
      claimedAmount: num.parse(amount),
      creditedAmount: null,
      hasReceipt: receiptToken != null,
      submittedAt: DateTime.now(),
      creditedAt: null,
      rejectReason: null,
      canCancel: true,
    );
    _topUps.insert(0, topUp);
    return _later(topUp, 300);
  }

  @override
  Future<List<TopUp>> topUps() => _later(List.of(_topUps));

  @override
  Future<TopUp> cancelTopUp(String id, {required String idempotencyKey}) {
    final i = _topUps.indexWhere((t) => t.id == id);
    final t = _topUps[i];
    final cancelled = TopUp(
      id: t.id,
      number: t.number,
      method: t.method,
      reference: t.reference,
      status: TopUpStatus.cancelled,
      claimedAmount: t.claimedAmount,
      creditedAmount: null,
      hasReceipt: t.hasReceipt,
      submittedAt: t.submittedAt,
      creditedAt: null,
      rejectReason: null,
      canCancel: false,
    );
    _topUps[i] = cancelled;
    return _later(cancelled, 200);
  }

  @override
  Future<List<CustomerInvoice>> invoices() => _later(const <CustomerInvoice>[]);

  // Tax invoices are live (backend spec 016): the mock has none to open.
  @override
  Future<CustomerInvoice> invoice(String id) => Future.error(StateError('Invoices are live.'));

  @override
  Future<InvoiceFile> invoicePdf(String id, String number) => Future.error(StateError('Invoices are live.'));

  @override
  Future<InvoiceFile> creditNotePdf(String id, String number) => Future.error(StateError('Invoices are live.'));
}

/// The prototype's sample profile, shown while signed out. Everything else on
/// the account needs the backend (spec 017, [ApiAccountRepository]).
class MockAccountRepository implements AccountRepository {
  static Never _live() => throw UnsupportedError('The account needs the backend.');

  @override
  Future<UserProfile> profile() => _later(mockProfile, 0);

  @override
  Future<PhoneChallenge> requestPhoneChange(String phone, {required String idempotencyKey}) => _live();

  @override
  Future<DateTime?> confirmPhoneChange(String challengeId, String code, {required String idempotencyKey}) => _live();

  @override
  Future<String> requestEmailChange(String email, {required String idempotencyKey}) => _live();

  @override
  Future<String> readEmailLink(String token) => _live();

  @override
  Future<DateTime?> confirmEmailLink(String token) => _live();

  @override
  Future<int> changePassword({required String current, required String next, required String idempotencyKey}) => _live();

  @override
  Future<List<AccountSession>> sessions() async => const [];

  @override
  Future<void> signOutSession(String id, {required String idempotencyKey}) => _live();

  @override
  Future<InboxPage> inbox({String? cursor}) async => const InboxPage(items: [], nextCursor: null, unread: 0);

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> markRead(String id, {required String idempotencyKey}) async {}

  @override
  Future<void> markAllRead({required String idempotencyKey}) async {}

  @override
  Future<List<SavedPiece>> saved({String? listingId}) async => const [];

  @override
  Future<void> save(String listingId, {required String idempotencyKey}) => _live();

  @override
  Future<void> unsave(String listingId) => _live();

  @override
  Future<List<CloseBlocker>> closeCheck() => _live();

  @override
  Future<void> close({required String reason, String? note, required String idempotencyKey}) => _live();

  @override
  Future<String> report({required String listingId, required String reason, String? note, required String idempotencyKey}) => _live();

  @override
  Future<List<LegalEntry>> legalDocuments() => _live();

  @override
  Future<LegalDoc> legalDocument(String code) => _live();

  @override
  Future<SupportContacts> supportContacts() => _live();
}

class MockContentRepository implements ContentRepository {
  @override
  Future<List<FaqItem>> faq() => _later(mockFaq, 0);

  @override
  Future<List<Branch>> branches() => _later(mockBranches, 0);

  @override
  PromoCode? promo(String code) {
    for (final p in mockPromoCodes) {
      if (p.code == code.trim().toUpperCase()) return p;
    }
    return null;
  }
}
