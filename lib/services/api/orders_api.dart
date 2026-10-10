import '../../core/utils/format.dart';
import '../../models/buy_request.dart';
import '../../models/dispute.dart';
import '../../models/order.dart';
import '../../models/piece.dart';
import '../../models/reference.dart';
import '../media_picker.dart' show MediaKind;
import '../repositories.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Orders from the backend (spec 012, `/customer/me/orders*`). The Orders tab shows
/// the customer's orders, then their buy requests that were not accepted (spec 011):
/// an accepted request is the order itself. Every write carries an idempotency key:
/// reuse it when retrying the same tap, so the backend replays the first answer and
/// never moves money twice.
class ApiOrdersRepository implements OrdersRepository {
  ApiOrdersRepository(this._client, this._tokens, this._buyRequests);

  final ApiClient _client;
  final TokenStore _tokens;
  final BuyRequestsRepository _buyRequests;

  static const _base = '/customer/me/orders';

  bool get _signedIn => _tokens.accessToken != null || _tokens.refreshToken != null;

  @override
  Future<List<OrderCardData>> orders() async {
    final orders = await list();
    List<BuyRequest> mine;
    try {
      mine = await _buyRequests.mine();
    } on ApiException {
      mine = const [];
    }
    return [
      for (final o in orders) orderCard(o),
      for (final r in mine)
        if (r.state != BuyRequestState.accepted) requestCard(r),
    ];
  }

  @override
  Future<List<CustomerOrder>> list() async {
    if (!_signedIn) return const [];
    try {
      final res = await _client.get('$_base?per_page=100', auth: true);
      return [for (final row in (res?['data'] as List? ?? const [])) CustomerOrder.fromJson((row as Map).cast<String, dynamic>())];
    } on ApiException catch (e) {
      // Not verified yet: no order can exist.
      if (e.code == 'verification_required') return const [];
      rethrow;
    }
  }

  @override
  Future<CustomerOrder> show(String id) async => _one(await _client.get('$_base/${Uri.encodeComponent(id)}', auth: true));

  @override
  Future<CustomerOrder> cancel(String id, {required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/cancel', auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<CustomerOrder> decide(String id, {required bool accept, required String inspectionId, required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/decision', body: {'accept': accept, 'inspection_id': inspectionId}, auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<CustomerOrder> payBalance(String id, {required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/pay-balance', auth: true, idempotencyKey: idempotencyKey));

  @override
  Future<CustomerOrder> relist(String id, {required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/relist', auth: true, idempotencyKey: idempotencyKey));

  // ---- spec 014 ----

  /// `POST /customer/me/uploads` with `purpose=dispute_photo` or `proxy_id`.
  @override
  Future<String> upload(MediaKind kind, UploadFile file) async {
    final res = await _client.postMultipart('/customer/me/uploads', fields: {'purpose': kind.purpose}, files: [file], auth: true);
    return (res?['data'] as Map)['upload_token'] as String;
  }

  /// `POST /customer/me/orders/{id}/disputes` (201 `CustomerDispute`). Rate-limited: 5 a minute.
  @override
  Future<CustomerDispute> openDispute(String id, {required String reason, required String detail, List<String> photoTokens = const [], required String idempotencyKey}) async {
    final res = await _client.post(
      '$_base/${Uri.encodeComponent(id)}/disputes',
      body: {'reason': reason, 'detail': detail, if (photoTokens.isNotEmpty) 'photo_tokens': photoTokens},
      auth: true,
      idempotencyKey: idempotencyKey,
    );
    return CustomerDispute.fromJson(res?['data'])!;
  }

  /// `POST /customer/me/orders/{id}/extension-requests` (201, the order).
  @override
  Future<CustomerOrder> requestMoreTime(String id, {required String reason, required String detail, required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/extension-requests', body: {'reason': reason, 'detail': detail}, auth: true, idempotencyKey: idempotencyKey));

  /// `GET /reference/legal-documents/collection_proxy_authorisation` (public).
  @override
  Future<LegalDoc> proxyAuthorisation() async =>
      LegalDoc.fromJson(((await _client.get('/reference/legal-documents/collection_proxy_authorisation'))?['data'] as Map).cast<String, dynamic>());

  /// `POST /customer/me/orders/{id}/proxy` (trade gate). The phone is +E.164.
  @override
  Future<CustomerOrder> nameProxy(
    String id, {
    required String name,
    required String phone,
    required String idToken,
    required int authorisationId,
    required String idempotencyKey,
  }) async => _one(
    await _client.post(
      '$_base/${Uri.encodeComponent(id)}/proxy',
      body: {'name': name, 'phone': phone, 'id_upload_token': idToken, 'authorisation_id': authorisationId, 'authorisation_accepted': true},
      auth: true,
      idempotencyKey: idempotencyKey,
    ),
  );

  /// `POST /customer/me/orders/{id}/proxy/remove`.
  @override
  Future<CustomerOrder> removeProxy(String id, {required String idempotencyKey}) async =>
      _one(await _client.post('$_base/${Uri.encodeComponent(id)}/proxy/remove', auth: true, idempotencyKey: idempotencyKey));

  // ---- spec 018 ----

  /// `POST /customer/me/orders/{id}/free-relist` (trade gate, 201: the new listing and the order).
  @override
  Future<FreeRelisted> freeRelist(
    String id, {
    String? makingChargePerG,
    String? askingPrice,
    String? description,
    required int ownershipDocId,
    required String idempotencyKey,
  }) async {
    final res = await _client.post(
      '$_base/${Uri.encodeComponent(id)}/free-relist',
      body: {
        'making_charge_per_g': ?makingChargePerG,
        'asking_price': ?askingPrice,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        'ownership_legal_doc_id': ownershipDocId,
      },
      auth: true,
      idempotencyKey: idempotencyKey,
    );
    final data = (res?['data'] as Map).cast<String, dynamic>();
    return FreeRelisted(listingId: '${(data['listing'] as Map)['id']}', order: CustomerOrder.fromJson((data['order'] as Map).cast<String, dynamic>()));
  }

  /// `POST /customer/me/orders/{id}/rating` (verified gate, 201: the rating and the order).
  @override
  Future<CustomerOrder> rate(String id, {required int stars, String? note, required String idempotencyKey}) async {
    final res = await _client.post(
      '$_base/${Uri.encodeComponent(id)}/rating',
      body: {'stars': stars, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
      auth: true,
      idempotencyKey: idempotencyKey,
    );
    return CustomerOrder.fromJson(((res?['data'] as Map)['order'] as Map).cast<String, dynamic>());
  }

  CustomerOrder _one(Map<String, dynamic>? res) => CustomerOrder.fromJson((res?['data'] as Map).cast<String, dynamic>());

  /// What the card says for an order, by side and stage.
  static (String, Tone, OrderStage) statusOf(CustomerOrder o) {
    final back = o.sellerReturn;
    if (o.isSeller && o.frozen) return ('On hold', Tone.wait, OrderStage.waiting);
    if (o.isSeller) {
      return switch (o.stage) {
        CustomerOrderStage.bringPiece => ('Bring it to IGI', Tone.bad, OrderStage.action),
        CustomerOrderStage.atIgi => ('At IGI', Tone.wait, OrderStage.waiting),
        CustomerOrderStage.decide => ('The buyer is deciding', Tone.wait, OrderStage.waiting),
        CustomerOrderStage.pay => ('Waiting for the buyer to pay', Tone.wait, OrderStage.waiting),
        CustomerOrderStage.collect || CustomerOrderStage.done => ('Sold', Tone.ok, OrderStage.done),
        _ when back != null && back.codeAvailable => ('Your piece is back', Tone.bad, OrderStage.action),
        _ when back != null && back.windowPassed => ('Collect your piece', Tone.bad, OrderStage.action),
        _ => ('Cancelled', Tone.neutral, OrderStage.done),
      };
    }
    final inspection = o.inspection;
    if (o.frozen) return ('On hold', Tone.wait, OrderStage.waiting);
    return switch (o.stage) {
      CustomerOrderStage.bringPiece => ('Accepted', Tone.ok, OrderStage.waiting),
      CustomerOrderStage.atIgi => ('At IGI', Tone.wait, OrderStage.waiting),
      CustomerOrderStage.decide when inspection != null && inspection.pricePending => ("Waiting for Dahab's price", Tone.wait, OrderStage.waiting),
      CustomerOrderStage.decide => ('Decide on the new price', Tone.bad, OrderStage.action),
      CustomerOrderStage.pay => ('Pay the balance', Tone.bad, OrderStage.action),
      CustomerOrderStage.collect when o.collection?.windowPassed == true => ('Collection window passed', Tone.bad, OrderStage.action),
      CustomerOrderStage.collect => ('Ready to collect', Tone.ok, OrderStage.action),
      CustomerOrderStage.done => ('Finished', Tone.ok, OrderStage.done),
      _ => ('Cancelled', Tone.neutral, OrderStage.done),
    };
  }

  /// Why the sale ended, in plain words.
  static String cancelReasonText(CustomerOrder o) => switch (o.cancelReasonKind) {
    'seller' => o.isSeller ? 'You cancelled the sale. The buyer got their deposit back.' : 'The seller cancelled the sale. Your deposit came back in full.',
    'deadline_missed' =>
      o.isSeller
          ? 'The piece did not reach the branch in time, so the sale was cancelled. The buyer got their deposit back.'
          : 'The seller did not bring the piece in time. Your deposit came back in full.',
    'staff' => o.isSeller ? 'Dahab cancelled the sale.' : 'Dahab cancelled the sale. Your deposit came back in full.',
    'no_pay' => o.isSeller ? 'The buyer did not pay the balance in time.' : 'The balance was not paid in time, so the deposit was kept as the agreement says.',
    'no_answer' =>
      o.isSeller
          ? 'The buyer did not answer on the new price in time.'
          : 'You did not answer on the new price in time, so it counted as a decline. Your deposit came back in full.',
    'declined' => o.isSeller ? 'The buyer declined the new price.' : 'You declined the new price. Your deposit came back in full.',
    'inspection' => o.isSeller ? 'The piece did not match the listing at inspection.' : 'The piece did not match the listing at inspection. Your deposit came back in full.',
    'dispute' =>
      o.isSeller
          ? 'Dahab looked into a problem on this order and cancelled the sale.'
          : 'Dahab looked into a problem on this order and cancelled the sale. Your deposit came back in full.',
    _ => 'This sale was cancelled.',
  };

  /// An order as an Orders card. Its button opens the order.
  static OrderCardData orderCard(CustomerOrder o) {
    final (status, tone, stage) = statusOf(o);
    final weight = double.tryParse(o.weight ?? '');
    final lead = o.isSeller
        ? (stage == OrderStage.done && o.stage != CustomerOrderStage.cancelled ? 'You sold this' : 'You are selling')
        : (o.stage == CustomerOrderStage.done ? 'You bought this' : 'You are buying');
    final deadline = o.deadline;

    final rows = <KV>[
      KV('Order', o.orderRef),
      if (o.branchNameEn.isNotEmpty) KV('Branch', o.branchNameEn),
      if (o.amountDue != null) KV('Balance to pay', moneyOf(o.amountDue)) else KV('Price', moneyOf(o.finalTotal ?? o.lockedTotalPrice)),
      if (o.sellerProceeds != null) KV('You received', moneyOf(o.sellerProceeds), tone: Tone.ok),
      if (deadline != null) KV(_deadlineLabel(deadline.kind, o.isSeller), whenOf(deadline.at), tone: deadline.overdue ? Tone.bad : Tone.wait),
    ];

    return OrderCardData(
      id: 'order-${o.id}',
      title: pieceTitle(o.category, o.typeNameEn, o.karat),
      status: status,
      statusTone: tone,
      subtitle: weight == null ? lead : '$lead, ${weight.toStringAsFixed(2)} g',
      roleIcon: o.isSeller ? 'tag' : 'search',
      stage: stage,
      role: o.isSeller ? OrderRole.sell : OrderRole.buy,
      blocks: [
        RowsBlock(rows),
        if (o.stage == CustomerOrderStage.cancelled) TextBlock(cancelReasonText(o)),
        ActionsBlock([OrderAction(stage == OrderStage.action ? 'Open the order' : 'See the order', 'order:${o.id}', primary: stage == OrderStage.action)]),
      ],
      detailView: 'owner',
      pieceId: o.listingId,
    );
  }

  static String _deadlineLabel(String kind, bool seller) => switch (kind) {
    'reach_branch' => seller ? 'Bring it by' : 'The seller delivers by',
    'decision' => 'Decide by',
    'balance' => 'Pay by',
    'collect' => 'Collect by',
    'return' => 'Collect your piece by',
    _ => 'Deadline',
  };

  /// A buy request not accepted (yet) as an Orders card ("You are buying").
  static OrderCardData requestCard(BuyRequest r) {
    final weight = double.tryParse(r.weight ?? '');
    final subtitle = weight == null ? 'You are buying' : 'You are buying, ${weight.toStringAsFixed(2)} g';

    final (String status, Tone tone, OrderStage stage) = switch (r.state) {
      BuyRequestState.queued => ('In line', Tone.wait, OrderStage.waiting),
      BuyRequestState.accepted => ('Accepted', Tone.ok, OrderStage.waiting),
      BuyRequestState.releasedNotChosen => ('Not chosen', Tone.neutral, OrderStage.done),
      BuyRequestState.releasedDeclined => ('Declined', Tone.neutral, OrderStage.done),
      BuyRequestState.releasedExpired => ('No reply in time', Tone.neutral, OrderStage.done),
      BuyRequestState.withdrawnByBuyer => ('You left the queue', Tone.neutral, OrderStage.done),
      BuyRequestState.other => ('In progress', Tone.wait, OrderStage.waiting),
    };

    final blocks = <OrderBlock>[];
    if (r.state == BuyRequestState.queued) {
      final ahead = r.aheadCount ?? 0;
      blocks.add(
        RowsBlock([
          KV('Your price is fixed at', moneyOf(r.lockedTotalPrice)),
          KV('Held from your wallet', moneyOf(r.depositAmount)),
          if (r.placeInLine != null) KV('Your place in the queue', ahead == 0 ? '${ordinal(r.placeInLine!)}, next' : '${ordinal(r.placeInLine!)}, $ahead ahead of you'),
          KV('The seller replies before', whenOf(r.sellerReplyDeadline), tone: Tone.wait),
        ]),
      );
      blocks.add(const NoteBlock('info-circle', 'If the seller declines, takes a buyer ahead of you, or does not reply in time, your deposit comes back in full at once.'));
    } else {
      blocks.add(
        AmountBlock(
          caption: 'Deposit returned to your wallet',
          amount: '+ ${moneyOf(r.depositAmount)}',
          rows: [if (r.resolvedAt != null) KV('Returned on', whenOf(r.resolvedAt!))],
        ),
      );
    }

    return OrderCardData(
      id: 'br-${r.id}',
      title: r.pieceTitleEn,
      status: status,
      statusTone: tone,
      subtitle: subtitle,
      roleIcon: 'search',
      stage: stage,
      role: OrderRole.buy,
      blocks: blocks,
      detailView: r.state == BuyRequestState.queued ? 'requested' : 'cancelled',
      pieceId: r.listingId,
    );
  }
}

/// The figures of a 409 `insufficient_funds` on pay-balance, or null.
BalanceShortfall? balanceShortfallOf(ApiException e) {
  final d = (e.extra['details'] as Map?)?.cast<String, dynamic>();
  if (e.code != 'insufficient_funds' || d == null) return null;
  return BalanceShortfall(amountDue: '${d['amount_due']}', available: '${d['available']}', shortfall: '${d['shortfall']}');
}

/// One plain sentence per refusal on an order (backend spec 012).
String orderErrorMessage(ApiException e) => switch (e.code) {
  'illegal_order_transition' => 'This order has already moved on. Pull to refresh.',
  'balance_deadline_passed' => 'The time to pay the balance has passed.',
  'insufficient_funds' => 'Your wallet does not have enough to pay the balance.',
  'inspection_correction_not_allowed' => 'The inspection result was updated. Look at the new result before you decide.',
  'price_not_set' => "Dahab has not set the new price yet. We will tell you when it is ready.",
  'settlement_not_possible' => 'The price cannot be worked out right now. Try again in a moment.',
  'illegal_listing_transition' => 'This piece is no longer waiting for you at the branch.',
  'account_suspended' => 'Your account is suspended, so this is not possible right now.',
  'idempotency_in_progress' => 'We are still working on your last tap. Wait a moment.',
  'not_found' => 'This order is no longer available.',
  // Spec 014.
  'order_frozen' => 'This order is on hold while Dahab looks into a problem.',
  'dispute_already_raised' => 'You already reported a problem on this order.',
  'extension_request_pending' => 'You already asked for more time. We will answer soon.',
  'illegal_extension_request_transition' => 'This request was already answered.',
  'too_many_requests' => 'Too many reports in a minute. Wait a moment and try again.',
  'upload_token_invalid' => 'A photo did not upload properly. Add it again.',
  'declaration_required' => 'The authorisation changed. Read it again and tick the box.',
  // Spec 018.
  'free_relist_expired' => 'The time to relist this piece with no commission has passed.',
  'already_relisted' => 'You already put this piece back on the market.',
  'branch_options_required' => 'None of the branches this piece was offered at is open now. Contact us to relist it.',
  'ownership_declaration_required' => 'Confirm ownership to list the piece.',
  'rating_not_available' => 'This order cannot be rated yet.',
  'rating_closed' => 'The time to rate this order has passed.',
  'already_rated' => 'You already rated this order.',
  _ when e.isNetwork => 'Could not reach the server. Check your connection and try again.',
  _ => 'Something went wrong',
};
