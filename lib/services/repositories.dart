import '../models/account.dart';
import '../models/buy_request.dart';
import '../models/dispute.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/payout.dart';
import '../models/piece.dart';
import '../models/reference.dart';
import '../models/wallet.dart';
import 'api/api_client.dart' show UploadFile;
import 'media_picker.dart' show MediaKind;

/// Repository interfaces. The app only depends on these; the mock
/// implementations live in `mock_repositories.dart`. To go live, implement
/// these against the real API and swap them in `main.dart`.
abstract interface class CatalogRepository {
  /// The pieces on the market, newest first (backend spec 010). Public.
  Future<List<Piece>> pieces();

  /// One piece on the market. Throws `not_found` once it has left it.
  Future<PieceDetail> detail(String id);

  /// Saved pieces (no backend yet: mock).
  Future<List<Piece>> saved();
}

/// What the sell form reads before a listing exists (backend spec 010,
/// `GET /reference/*`). Public.
abstract interface class ReferenceRepository {
  Future<SellReference> sellReference();
}

/// The seller's own listings (backend spec 010, `/customer/me/listings*`).
/// Every write carries an idempotency key: reuse it when retrying the same
/// submission so the backend replays the first answer instead of acting twice.
abstract interface class ListingsRepository {
  /// Newest first. Empty when signed out or not verified yet.
  Future<List<Listing>> mine();

  Future<Listing> show(String id);

  /// Uploads one file for a listing (`listing_photo`, `listing_video`,
  /// `listing_invoice`, `stone_certificate`); returns its single-use token.
  Future<String> uploadMedia(String purpose, UploadFile file);

  Future<Listing> create(Map<String, dynamic> body, {required String idempotencyKey});

  Future<Listing> update(String id, Map<String, dynamic> body, {required String idempotencyKey});

  /// Sends a draft, or a listing sent back for changes, to Dahab's review.
  Future<Listing> submit(String id, {required String idempotencyKey});

  /// Takes a live listing off the market. Final.
  Future<Listing> withdraw(String id, {required String idempotencyKey});
}

/// Buy requests (backend spec 011): the buyer's side (`/customer/me/buy-requests*`)
/// and the seller's line (`/customer/me/listings/{id}/buy-requests|accept|decline`).
/// Every write carries an idempotency key; reuse it when retrying the same tap.
abstract interface class BuyRequestsRepository {
  /// The current deposit terms (`GET /reference/legal-documents/deposit_agreement`).
  Future<DepositTerms> depositTerms();

  /// Joins the line: holds the deposit and locks the price. Throws `insufficient_funds`
  /// (with the shortfall), `price_moved` (with the fresh price) and the other refusals.
  Future<BuyRequest> send({required String listingId, required String confirmedPrice, required int termsId, required String idempotencyKey});

  /// Newest first; optionally one listing and/or one state. Empty when signed out.
  Future<List<BuyRequest>> mine({String? listingId, String? state});

  /// Leaves the line; the deposit comes back at once.
  Future<BuyRequest> leave(String id, {required bool notifyWhenFree, required String idempotencyKey});

  /// The line on the seller's own listing.
  Future<SellerQueue> queue(String listingId);

  /// Accepts the first in line at one of the listing's branches; returns the order.
  Future<OrderSummary> accept(String listingId, String requestId, int branchId, {required String idempotencyKey});

  /// Declines the first in line (no reason).
  Future<void> decline(String listingId, String requestId, {required String idempotencyKey});
}

/// Orders (backend spec 012, `/customer/me/orders*`): the customer's own, as the
/// buyer or the seller. Every write carries an idempotency key; reuse it when
/// retrying the same tap. Each write answers with the order, codes included.
abstract interface class OrdersRepository {
  /// The Orders cards: the orders, then the buy requests not accepted yet (spec 011).
  Future<List<OrderCardData>> orders();

  /// Newest first. Empty when signed out or not verified yet.
  Future<List<CustomerOrder>> list();

  /// One order; the owner's code is included while it can be used.
  Future<CustomerOrder> show(String id);

  /// The seller cancels before delivering; the buyer is refunded and it counts against the seller.
  Future<CustomerOrder> cancel(String id, {required String idempotencyKey});

  /// The buyer accepts or declines the price after inspection. [inspectionId] is the result decided on.
  Future<CustomerOrder> decide(String id, {required bool accept, required String inspectionId, required String idempotencyKey});

  /// The buyer pays the balance from the wallet. Throws `insufficient_funds` (with the
  /// shortfall), `balance_deadline_passed` and the other refusals.
  Future<CustomerOrder> payBalance(String id, {required String idempotencyKey});

  /// The seller puts a returned piece back on the market instead of collecting it.
  Future<CustomerOrder> relist(String id, {required String idempotencyKey});

  // ---- spec 014 ----

  /// Stores a dispute photo or a proxy's ID photo and returns its upload token.
  Future<String> upload(MediaKind kind, UploadFile file);

  /// Reports a problem: the order is frozen while Dahab looks at it.
  Future<CustomerDispute> openDispute(String id, {required String reason, required String detail, List<String> photoTokens = const [], required String idempotencyKey});

  /// The seller asks for more time to bring the piece.
  Future<CustomerOrder> requestMoreTime(String id, {required String reason, required String detail, required String idempotencyKey});

  /// The collection authorisation the buyer accepts when naming someone else.
  Future<LegalDoc> proxyAuthorisation();

  /// The buyer names someone else to collect; replaces anyone named before.
  Future<CustomerOrder> nameProxy(String id, {required String name, required String phone, required String idToken, required int authorisationId, required String idempotencyKey});

  /// The buyer withdraws the person named; only the buyer can collect again.
  Future<CustomerOrder> removeProxy(String id, {required String idempotencyKey});
}

abstract interface class WalletRepository {
  Future<WalletSummary> summary();
  Future<List<WalletTxn>> transactions();

  /// What each buy request and order holds now (backend spec 015).
  Future<HeldItems> held();

  /// Where to send money and the customer's reference (backend spec 009).
  Future<TopUpMethods> topUpMethods();

  /// Uploads a top-up receipt (image or PDF); returns its single-use token.
  Future<String> uploadReceipt(UploadFile file);

  /// "I've sent the transfer": a pending notice; no money moves. Reuse the same
  /// [idempotencyKey] when retrying the same submission.
  Future<TopUp> submitTopUp({required String amount, required int accountId, String? receiptToken, required String idempotencyKey});

  /// The customer's own notices and hand credits, newest first.
  Future<List<TopUp>> topUps();

  /// Withdraws a pending notice.
  Future<TopUp> cancelTopUp(String id, {required String idempotencyKey});

  Future<List<InvoiceSummary>> invoices();
}

abstract interface class AccountRepository {
  Future<UserProfile> profile();
  Future<List<DeviceSession>> devices();
  Future<List<AppNotification>> notifications();
  Future<List<NotificationPref>> notificationPrefs();
}

/// Payout accounts and withdrawals (backend spec 013). Every change sends an
/// `Idempotency-Key`; account changes answer with the whole [PayoutView].
abstract interface class PayoutRepository {
  /// The accounts, the pause and the recent changes. Empty when signed out or
  /// not verified yet (`verification_required`).
  Future<PayoutView> accounts();

  /// The current payout-account declaration (`/reference/legal-documents/payout_account_declaration`).
  Future<LegalDoc> declaration();

  Future<PayoutView> add({required String bankName, required String accountName, required String number, required int declarationId, required String idempotencyKey});

  /// Makes a verified account the one in use. Returns the numbers of the
  /// withdrawals this cancelled (`meta.cancelled_withdrawals`).
  Future<(PayoutView, List<String>)> use(String id, {required String idempotencyKey});

  /// Cancels a request under review, removes a verified account, or schedules
  /// the removal while a withdrawal to it is open.
  Future<PayoutView> remove(String id, {required String idempotencyKey});

  /// Keeps an account that is being removed.
  Future<PayoutView> keep(String id, {required String idempotencyKey});

  /// Emails the confirmation link for this amount and account.
  Future<WithdrawalConfirmation> requestConfirmation({required String amount, required String accountId, required String idempotencyKey});

  /// Polled while the email row says Waiting.
  Future<WithdrawalConfirmation> confirmation(String id);

  Future<CustomerWithdrawal> submit({required String confirmationId, required String amount, required String accountId, required String idempotencyKey});

  /// Newest first; `state` is `open` or `closed`.
  Future<List<CustomerWithdrawal>> withdrawals({String? state});

  Future<CustomerWithdrawal> cancel(String id, {required String idempotencyKey});

  /// The email link's page (no sign-in).
  Future<LinkConfirmation> readLink(String token);
  Future<LinkConfirmation> confirmLink(String token);
}

abstract interface class ContentRepository {
  Future<List<FaqItem>> faq();
  Future<List<Branch>> branches();
  PromoCode? promo(String code);
}
