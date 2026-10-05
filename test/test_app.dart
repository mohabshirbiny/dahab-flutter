import 'dart:convert';

import 'package:dahab_app/app.dart';
import 'package:dahab_app/core/i18n/i18n.dart';
import 'package:dahab_app/services/account_controller.dart';
import 'package:dahab_app/services/api/api_client.dart';
import 'package:dahab_app/services/api/buy_requests_api.dart';
import 'package:dahab_app/services/api/orders_api.dart';
import 'package:dahab_app/services/api/listings_api.dart';
import 'package:dahab_app/services/api/market_api.dart';
import 'package:dahab_app/services/api/payout_api.dart';
import 'package:dahab_app/services/api/prices_api.dart';
import 'package:dahab_app/services/api/token_store.dart';
import 'package:dahab_app/services/api/wallet_api.dart';
import 'package:dahab_app/services/app_session.dart';
import 'package:dahab_app/services/auth/auth_api.dart';
import 'package:dahab_app/services/auth/auth_controller.dart';
import 'package:dahab_app/services/live_rates.dart';
import 'package:dahab_app/services/media_picker.dart';
import 'package:dahab_app/services/mock_repositories.dart';
import 'package:dahab_app/services/payout_controller.dart';
import 'package:dahab_app/services/repositories.dart';
import 'package:dahab_app/services/sell_draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads the bundled fonts so layout in tests matches the browser.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await load('Inter', ['assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Medium.ttf', 'assets/fonts/Inter-SemiBold.ttf']);
  await load('IBMPlexSansArabic', ['assets/fonts/IBMPlexSansArabic-Regular.ttf', 'assets/fonts/IBMPlexSansArabic-Medium.ttf', 'assets/fonts/IBMPlexSansArabic-SemiBold.ttf']);
  await load('InstrumentSerif', ['assets/fonts/InstrumentSerif-Regular.ttf']);
  await load('PlayfairDisplay', ['assets/fonts/PlayfairDisplay-SemiBold.ttf']);
}

/// A stand-in for the Laravel API that answers with the same JSON shapes as
/// the real controllers. Code `123456` is right; anything else is wrong.
class FakeBackend {
  final requests = <http.Request>[];

  /// The signed-in customer is still `pending_verification`. Since backend spec 002
  /// such a customer can sign in; only trading actions are refused.
  bool pendingAccount = false;

  /// Backend spec 007: the signed-in customer is suspended for this reason code.
  /// They can still sign in and read; trading is refused with `account_suspended`.
  String? suspendedReason;

  /// `POST /customer/auth/logout-all` was called.
  bool loggedOutEverywhere = false;

  /// Answer the login with this refusal instead of the OTP challenge.
  String? refuseLoginWith;

  /// Backend spec 008: the signed-in customer's wallet, as the API sends it.
  Map<String, dynamic> wallet = {'available': '0.0000', 'held': '0.0000', 'total': '0.0000', 'currency': 'EGP'};

  /// Newest first, the shape of `GET /customer/me/wallet/transactions` rows.
  List<Map<String, dynamic>> walletRows = [];

  /// Backend spec 015: `GET /customer/me/wallet/held` — what each request and order holds.
  Map<String, dynamic> held = {'total': '0.0000', 'items': <Map<String, dynamic>>[]};

  /// Backend spec 015: false makes `/reference/gold-prices` and `/reference/quote` answer `price_unavailable`.
  bool pricesAvailable = true;

  /// Backend spec 015: today's prices, the shape of `GET /reference/gold-prices`.
  Map<String, dynamic> goldPrices = {
    'price_at': '2026-10-04T10:00:00+03:00',
    'feed_state': 'live',
    'karats': [
      {'code': 24, 'label': '24K', 'sellers_get': '5985.0090', 'buyers_pay': '6002.9910'},
      {'code': 21, 'label': '21K', 'sellers_get': '5236.8750', 'buyers_pay': '5263.1250'},
      {'code': 18, 'label': '18K', 'sellers_get': '4491.0000', 'buyers_pay': '4500.0000'},
    ],
  };

  /// Backend spec 009: the customer's notices, newest first, as the API sends them.
  List<Map<String, dynamic>> topUps = [];
  int _topUpNo = 128;

  // ---- backend spec 013: payout accounts and withdrawals ----

  /// The customer's accounts as the API sends them (`CustomerPayoutAccount`), the one in use first.
  List<Map<String, dynamic>> payoutAccounts = [];

  /// `pause.until` of `GET /customer/me/payout-accounts`, or null.
  String? pauseUntil;
  List<Map<String, dynamic>> payoutChanges = [];

  /// Newest first (`CustomerWithdrawal`).
  List<Map<String, dynamic>> withdrawals = [];

  /// Confirmations by id; `token` is what the email link carries.
  final confirmations = <String, Map<String, dynamic>>{};
  int _payoutNo = 1;
  int _withdrawalNo = 12;

  static const payoutDeclaration = {
    'id': 9,
    'code': 'payout_account_declaration',
    'version': 1,
    'body_en': 'I confirm this bank account is in my own name and the details are correct.',
    'body_ar': 'أقر إن الحساب البنكي ده باسمي وإن البيانات صحيحة.',
  };

  static Map<String, dynamic> payoutAccount(String id, {String bank = 'CIB', String last4 = '4417', String state = 'active', bool inUse = false, String? refusal}) => {
    'id': id,
    'bank_name': bank,
    'account_name': 'Mona Hassan Ibrahim',
    'number_masked': '•••• $last4',
    'kind': 'iban',
    'state': state,
    'in_use': inUse,
    'added_at': '2026-05-12T10:00:00+03:00',
    'checked_at': state == 'active' ? '2026-05-12T12:00:00+03:00' : null,
    'refusal_reason': refusal,
    'can': {'use': state == 'active' && !inUse, 'remove': state == 'pending_review' || state == 'active', 'keep': state == 'removing'},
  };

  /// The email link was opened and confirmed (what `/withdrawal-confirmations/confirm` does).
  void openEmailLink(String confirmationId) => confirmations[confirmationId]!['state'] = 'confirmed';

  String tokenFor(String confirmationId) => confirmations[confirmationId]!['token'] as String;

  Map<String, dynamic> get _payoutView => {
    'accounts': payoutAccounts,
    'pause': pauseUntil == null ? null : {'until': pauseUntil},
    'recent_changes': payoutChanges,
  };

  Map<String, dynamic> _confirmation(Map<String, dynamic> c, {bool withEmail = false}) => {
    'id': c['id'],
    'state': c['state'],
    'amount': c['amount'],
    'account': {'id': c['account_id'], 'bank_name': 'CIB', 'number_masked': '•••• 4417'},
    'expires_at': '2026-10-03T12:30:00+03:00',
    'email_masked': withEmail ? 'm•••@email.com' : null,
  };

  /// Moves money like the backend's `withdrawal` entries: hold (available → held) or back.
  void _moveForWithdrawal(num amount) {
    String f(num v) => v.toStringAsFixed(4);
    final available = num.parse('${wallet['available']}') - amount;
    final pending = num.parse('${wallet['pending_withdrawals'] ?? '0'}') + amount;
    final held = num.parse('${wallet['held']}') + amount;
    wallet = {...wallet, 'available': f(available), 'held': f(held), 'held_on_orders': f(held - pending), 'pending_withdrawals': f(pending)};
  }

  // ---- backend spec 010: reference data, the market and the seller's listings ----

  static const marketRingId = '0199a000-0000-7000-8000-000000000001';
  static const marketBraceletId = '0199a000-0000-7000-8000-000000000002';

  static const branches = [
    {'id': 1, 'name_en': 'Nasr City', 'name_ar': 'مدينة نصر', 'address_en': '12 Abbas El Akkad', 'address_ar': '١٢ عباس العقاد'},
    {'id': 2, 'name_en': 'Maadi', 'name_ar': 'المعادي', 'address_en': 'Road 9', 'address_ar': 'شارع ٩'},
  ];

  static const pieceTypes = [
    {'id': 1, 'category': 'gold', 'name_en': 'Ring', 'name_ar': 'خاتم'},
    {'id': 2, 'category': 'gold', 'name_en': 'Earrings', 'name_ar': 'حلق'},
    {'id': 3, 'category': 'gold', 'name_en': 'Bracelet', 'name_ar': 'إسورة'},
    {'id': 11, 'category': 'diamond', 'name_en': 'Ring', 'name_ar': 'خاتم'},
    {'id': 21, 'category': 'gold_with_diamond', 'name_en': 'Ring', 'name_ar': 'خاتم'},
  ];

  static const declaration = {
    'id': 7,
    'code': 'ownership_declaration',
    'version': 1,
    'body_en': 'I confirm this piece is mine to sell and the details above are accurate.',
    'body_ar': 'أقر إن القطعة دي ملكي وإن البيانات اللي فوق صحيحة.',
  };

  static Map<String, dynamic> _media(String base, String id, String kind, {bool private = false, int position = 0}) => {
    'id': id,
    'kind': kind,
    'is_private': private,
    'mime': kind == 'video' ? 'video/mp4' : 'image/png',
    'position': position,
    'url': '$base/media/$id',
  };

  static Map<String, dynamic> marketRow(
    String id, {
    int typeId = 1,
    String typeEn = 'Ring',
    String typeAr = 'خاتم',
    int karat = 21,
    String weight = '8.000',
    String making = '250.0000',
    String price = '58200.0000',
    bool mine = false,
  }) => {
    'id': id,
    'category': 'gold',
    'piece_type': {'id': typeId, 'name_en': typeEn, 'name_ar': typeAr},
    'karat': karat,
    'weight_g': weight,
    'making_charge_per_g': making,
    'current_price': price,
    'price_available': true,
    'price_is_indicative': true,
    'photos': [_media('/api/v1/market/listings/$id', 'ph-$id', 'photo')],
    'branch_options': [
      {'id': 1, 'name_en': 'Nasr City', 'name_ar': 'مدينة نصر'},
    ],
    'queue_count': 0,
    'listed_at': '2026-09-20T10:00:00+03:00',
    'is_mine': mine,
  };

  /// `GET /market/listings`, newest first.
  List<Map<String, dynamic>> market = [
    marketRow(marketRingId),
    marketRow(marketBraceletId, typeId: 3, typeEn: 'Bracelet', typeAr: 'إسورة', karat: 18, weight: '5.200', making: '180.0000', price: '32270.0000', mine: true),
  ];

  /// The signed-in seller's listings, newest first (contract "Listing (seller view)").
  List<Map<String, dynamic>> listings = [];

  /// The `purpose` of every file sent to `POST /customer/me/uploads`.
  final uploads = <String>[];

  // ---- backend spec 011: buy requests ----

  /// The signed-in buyer's requests, newest first (contract "BuyRequest").
  List<Map<String, dynamic>> buyRequests = [];

  /// The line on the signed-in seller's listings, by listing id (contract "SellerQueueItem").
  Map<String, List<Map<String, dynamic>>> queues = {};

  // ---- backend spec 016: tax invoices ----

  /// The customer's invoices, newest first (contract "CustomerInvoice"), each with its detail.
  List<Map<String, dynamic>> invoices = [];

  static Map<String, dynamic> invoice(String id, {bool seller = true, bool ready = true, List<Map<String, dynamic>> creditNotes = const []}) => {
    'id': id,
    'number': 'DH-2026-000004-${seller ? 'S' : 'B'}',
    'party': seller ? 'seller' : 'buyer',
    'order_id': 'ord-4',
    'order_ref': 'DH-2026-000004',
    'issued_at': '2026-10-05T14:05:00+03:00',
    'net': seller ? '600.0000' : '55631.2500',
    'vat': seller ? '84.0000' : '0.0000',
    'gross': seller ? '684.0000' : '55631.2500',
    'credited': creditNotes.isEmpty ? '0.0000' : '100.0000',
    'remaining': seller ? '684.0000' : '55631.2500',
    'status': creditNotes.isEmpty ? 'issued' : 'partly_credited',
    'document_ready': ready,
    'vat_rate': seller ? '14.000' : '0.000',
    'lines': {
      'category': 'gold',
      'karat': 21,
      'karat_label': '21K',
      'piece_type_en': 'Ring',
      'piece_type_ar': 'خاتم',
      'weight_g': '10.000',
      'unit_rate': seller ? '5236.8750' : '5263.1250',
      'gold_value': seller ? '52368.7500' : '52631.2500',
      'making_total': '3000.0000',
      'asking_price': null,
      'subtotal': seller ? '55368.7500' : '55631.2500',
      if (seller) 'commission_pct': '20',
      if (seller) 'paid_to_wallet': '54684.7500',
    },
    'issuer': null,
    'credit_notes': creditNotes,
  };

  // ---- backend spec 012: orders ----

  /// The signed-in customer's orders, newest first (contract "CustomerOrder"), with
  /// the owner's codes under `collection_code` / `return_code` (sent only in a detail).
  List<Map<String, dynamic>> orders = [];

  static Map<String, dynamic> order(
    String id, {
    String role = 'buyer',
    String state = 'awaiting_delivery',
    String stage = 'bring_piece',
    List<String> actions = const [],
    Map<String, dynamic>? deadline,
    Map<String, dynamic>? inspection,
    String? amountDue,
    String? finalTotal,
    String? sellerProceeds,
    Map<String, dynamic>? collection,
    Map<String, dynamic>? sellerReturn,
    Map<String, dynamic>? cancel,
    String? collectionCode,
    String? returnCode,
    Map<String, dynamic>? invoice,
  }) => {
    'id': id,
    'order_ref': 'DH-2026-00000${id.substring(id.length - 1)}',
    'role': role,
    'state': state,
    'stage': stage,
    'piece': {
      'listing_id': marketRingId,
      'category': 'gold',
      'piece_type': {'id': 1, 'name_en': 'Ring', 'name_ar': 'خاتم'},
      'karat': 21,
      'weight_g': '8.000',
      'listing_state': 'accepted',
      'photo': null,
    },
    'branch': {'id': 1, 'name_en': 'Nasr City', 'name_ar': 'مدينة نصر', 'address_en': '12 Abbas El Akkad', 'address_ar': '', 'hours': []},
    'counterparty_ref': '6620',
    'locked_total_price': '58200.0000',
    'deposit_amount': '11640.0000',
    'deadline': deadline,
    'amount_due': amountDue,
    'final_total': finalTotal,
    'seller_proceeds': sellerProceeds,
    'inspection': inspection,
    'collection': collection,
    'seller_return': sellerReturn,
    'cancel': cancel,
    'invoice': invoice,
    'actions': actions,
    'timeline': [
      {
        'event': 'accepted',
        'at': '2026-10-01T16:00:00+03:00',
        'detail': {'state': 'awaiting_delivery'},
      },
    ],
    '_collection_code': collectionCode,
    '_return_code': returnCode,
  };

  /// What the API sends: codes only in a detail, never the private keys.
  static Map<String, dynamic> orderOut(Map<String, dynamic> o, {bool detail = false}) => {
    for (final e in o.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
    if (detail) 'collection_code': o['_collection_code'],
    if (detail) 'return_code': o['_return_code'],
  };

  // ---- backend spec 014 ----

  static const proxyAuthorisation = {
    'id': 11,
    'code': 'collection_proxy_authorisation',
    'version': 1,
    'body_en': 'I authorise this person to collect the piece for me and take responsibility for choosing them.',
    'body_ar': 'أنا بفوّض الشخص ده يستلم القطعة بدالي ومسؤول عن اختياره.',
  };

  int _disputeNo = 41;

  static const depositTerms = {
    'id': 7,
    'code': 'deposit_agreement',
    'version': 1,
    'body_en': 'I agree that the deposit shown before I send this request is held from my wallet while my request waits.',
    'body_ar': 'موافق إن العربون يتحجز من محفظتي طول ما طلبي مستني.',
  };

  static Map<String, dynamic> buyRequest(String id, String listingId, String state, {int? place, int? ahead}) => {
    'id': id,
    'state': state,
    'listing': {
      'id': listingId,
      'category': 'gold',
      'piece_type': {'id': 1, 'name_en': 'Ring', 'name_ar': 'خاتم'},
      'karat': 21,
      'weight_g': '8.000',
      'state': 'reserved',
      'queue_count': 2,
      'photo': null,
    },
    'queue_position': place ?? 1,
    'place_in_line': place,
    'ahead_count': ahead,
    'locked_unit_rate': '6975.0000',
    'locked_total_price': '58200.0000',
    'deposit_amount': '11640.0000',
    'requested_at': '2026-09-30T19:00:00+03:00',
    'seller_reply_deadline': '2026-10-02T19:00:00+03:00',
    'resolved_at': state == 'queued' ? null : '2026-09-30T20:00:00+03:00',
    'notify_when_free': false,
    'order': null,
  };
  int _listingNo = 1;

  /// One of the seller's listings, as the API sends it.
  static Map<String, dynamic> listing(String id, String state, {String? staffMessage, int photos = 2, String weight = '8.000', String making = '300.0000'}) {
    final base = '/api/v1/customer/me/listings/$id';
    final editable = state == 'draft' || state == 'changes_requested';
    return {
      'id': id,
      'state': state,
      'category': 'gold',
      'piece_type': {'id': 1, 'name_en': 'Ring', 'name_ar': 'خاتم'},
      'karat': 21,
      'stated_weight_g': weight,
      'making_charge_per_g': making,
      'asking_price': null,
      'description': '21K gold ring, worn twice, small scratch on the inner band.',
      'media': [for (var i = 0; i < photos; i++) _media(base, 'm$i-$id', 'photo', position: i)],
      'branch_options': [
        {'id': 1, 'name_en': 'Nasr City', 'name_ar': 'مدينة نصر', 'is_enabled': true},
      ],
      'current_price': '58200.0000',
      'price_available': true,
      'price_is_indicative': true,
      'you_would_receive': '57744.0000',
      'staff_message': staffMessage,
      'staff_message_at': staffMessage == null ? null : '2026-09-29T09:00:00+03:00',
      'created_at': '2026-09-28T10:00:00+03:00',
      'listed_at': state == 'live' ? '2026-09-28T12:00:00+03:00' : null,
      'state_changed_at': '2026-09-28T12:00:00+03:00',
      'can_edit': editable,
      'can_submit': editable,
      'can_withdraw': state == 'live',
    };
  }

  Map<String, dynamic> _moved(Map<String, dynamic> l, String state) => {...l, 'state': state, 'can_edit': false, 'can_submit': false, 'can_withdraw': state == 'live'};

  /// A 1×1 PNG, served for every media file.
  static final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

  static const topUpMethods = {
    'reference': 'DAHAB-396233',
    'methods': [
      {
        'method': 'bank_transfer',
        'accounts': [
          {
            'id': 1,
            'method': 'bank_transfer',
            'label': 'CIB',
            'details': [
              {'key': 'bank_name', 'value': 'CIB'},
              {'key': 'account_holder', 'value': 'Dahab Trading'},
              {'key': 'account_number', 'value': '1000 4417 2026'},
            ],
            'daily_limit': null,
            'provider_fee_percent': null,
            'note': 'Dahab takes nothing on top-ups.',
          },
        ],
      },
      {
        'method': 'instapay',
        'accounts': [
          {
            'id': 2,
            'method': 'instapay',
            'label': 'InstaPay',
            'details': [
              {'key': 'instapay_address', 'value': 'dahab@instapay'},
            ],
            'daily_limit': '70000.0000',
            'provider_fee_percent': '0.500',
            'note': 'The fee is charged by InstaPay, not by Dahab.',
          },
        ],
      },
    ],
  };

  Map<String, dynamic> get _customer {
    if (suspendedReason != null) {
      return {...customer, 'status': 'suspended', 'is_suspended': true, 'suspended_reason': suspendedReason, 'suspended_at': '2026-09-28T10:00:00+03:00', 'trade_allowed': false};
    }
    return pendingAccount ? {...customer, 'status': 'pending_verification', 'is_verified': false, 'trade_allowed': false} : customer;
  }

  static const customer = {
    'id': '01a0d57e-6109-7352-be70-c6b7b19a0278',
    'display_ref': '396233',
    'phone': '+201012344417',
    'email': 'mona.h@email.com',
    'email_verified_at': '2026-09-24T22:17:04+03:00',
    'full_name': 'Mona Hassan Ibrahim',
    'preferred_lang': 'en',
    'governorate': 'cairo',
    'status': 'active',
    'is_verified': true,
    'is_suspended': false,
    'suspended_reason': null,
    'suspended_at': null,
    'trade_allowed': true,
    'created_at': '2026-05-12T10:00:00+03:00',
  };

  static final session = {
    'token_type': 'Bearer',
    'access_token': '1|access',
    'access_token_expires_at': DateTime.now().add(const Duration(minutes: 15)).toUtc().toIso8601String(),
    'refresh_token': '2|refresh',
    'refresh_token_expires_at': DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
    'family_id': 'fam',
  };

  MockClient get client => MockClient((req) async {
    requests.add(req);
    final path = req.url.path.replaceFirst('/api/v1', '');
    // A multipart body carries file bytes: it is never decoded as text.
    final multipart = req.headers['content-type']?.startsWith('multipart') == true;
    final body = multipart || req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
    http.Response json(int status, Object data) => http.Response(jsonEncode(data), status, headers: {'content-type': 'application/json'});
    http.Response error(int status, String code) => json(status, {'message': code, 'code': code});
    final challenge = {
      'otp_required': true,
      'otp_channel': 'sms',
      'challenge_id': 'c0ffee00-0000-4000-8000-000000000001',
      'expires_at': DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String(),
      'resend_available_at': DateTime.now().add(const Duration(seconds: 60)).toUtc().toIso8601String(),
    };

    // Backend spec 016: the customer's own invoices and their PDFs.
    if (path == '/customer/me/invoices') {
      if (pendingAccount) return error(403, 'verification_required');
      final rows = [
        for (final i in invoices)
          {...i}
            ..remove('lines')
            ..remove('credit_notes')
            ..remove('issuer')
            ..remove('vat_rate'),
      ];
      return json(200, {
        'data': [
          for (final r in rows)
            {
              ...r,
              'piece': {'category': 'gold', 'karat': 21, 'piece_type_en': 'Ring', 'piece_type_ar': 'خاتم', 'weight_g': '10.000', 'subtotal': r['gross']},
            },
        ],
        'meta': {'per_page': 50, 'next_cursor': null},
      });
    }
    final invoicePath = RegExp(r'^/customer/me/(invoices|credit-notes)/([^/]+)(/pdf)?$').firstMatch(path);
    if (invoicePath != null) {
      final id = invoicePath.group(2);
      if (invoicePath.group(1) == 'credit-notes') {
        final known = invoices.any((i) => (i['credit_notes'] as List).any((n) => (n as Map)['id'] == id));
        return known ? http.Response.bytes(utf8.encode('%PDF-fake $id'), 200, headers: {'content-type': 'application/pdf'}) : error(404, 'not_found');
      }
      final i = invoices.where((x) => x['id'] == id).firstOrNull;
      if (i == null) return error(404, 'not_found');
      if (invoicePath.group(3) == null) return json(200, {'data': i});
      return i['document_ready'] == true ? http.Response.bytes(utf8.encode('%PDF-fake $id'), 200, headers: {'content-type': 'application/pdf'}) : error(409, 'document_not_ready');
    }

    // Backend spec 009: trade gate for the receiving details and new notices;
    // a suspended customer may still list and cancel their own notices.
    String? tradeRefusal() => pendingAccount ? 'verification_required' : (suspendedReason != null ? 'account_suspended' : null);
    final cancel = RegExp(r'^/customer/me/wallet/topups/([^/]+)/cancel$').firstMatch(path);
    if (cancel != null) {
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final i = topUps.indexWhere((t) => t['id'] == cancel.group(1));
      if (i < 0) return error(404, 'not_found');
      if (topUps[i]['status'] != 'pending') return error(409, 'illegal_topup_transition');
      topUps[i] = {...topUps[i], 'status': 'cancelled', 'can_cancel': false};
      return json(200, {'data': topUps[i]});
    }

    // ---- backend spec 013 ----
    if (path == '/reference/legal-documents/payout_account_declaration') return json(200, {'data': payoutDeclaration});
    if (path == '/customer/me/payout-accounts') {
      if (req.method == 'GET') {
        if (pendingAccount) return error(403, 'verification_required');
        return json(200, {'data': _payoutView});
      }
      final refused = tradeRefusal();
      if (refused != null) return error(403, refused);
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final number = '${body['account_number_or_iban'] ?? ''}'.replaceAll(' ', '');
      if (number.length < 10) {
        return json(422, {
          'message': 'bad',
          'code': 'validation_failed',
          'errors': {
            'account_number_or_iban': ['Enter an Egyptian IBAN or a bank account number.'],
          },
        });
      }
      if (body['declaration_id'] != payoutDeclaration['id'] || body['declaration_accepted'] != true) return error(422, 'declaration_required');
      final account = {
        ...payoutAccount('pa-${_payoutNo++}', bank: '${body['bank_name']}', last4: number.substring(number.length - 4), state: 'pending_review'),
        'account_name': body['account_name'],
      };
      payoutAccounts.add(account);
      payoutChanges.insert(0, {
        'kind': 'added',
        'account': {'bank_name': account['bank_name'], 'number_masked': account['number_masked']},
        'at': '2026-10-03T10:00:00+03:00',
        'by': 'you',
      });
      return json(201, {'data': _payoutView});
    }
    final payoutAction = RegExp(r'^/customer/me/payout-accounts/([^/]+)/(use|remove|keep)$').firstMatch(path);
    if (payoutAction != null) {
      final refused = tradeRefusal();
      if (refused != null) return error(403, refused);
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final i = payoutAccounts.indexWhere((a) => a['id'] == payoutAction.group(1));
      if (i < 0) return error(404, 'not_found');
      final a = payoutAccounts[i];
      final cancelled = <String>[];
      switch (payoutAction.group(2)) {
        case 'use':
          if (a['state'] != 'active' || a['in_use'] == true) return error(409, 'illegal_payout_account_transition');
          final first = !payoutAccounts.any((x) => x['in_use'] == true);
          for (var j = 0; j < payoutAccounts.length; j++) {
            final x = payoutAccounts[j];
            payoutAccounts[j] = payoutAccount(
              '${x['id']}',
              bank: '${x['bank_name']}',
              last4: '${x['number_masked']}'.substring('${x['number_masked']}'.length - 4),
              state: '${x['state']}',
              inUse: j == i,
            );
          }
          if (!first) {
            for (var j = 0; j < withdrawals.length; j++) {
              final w = withdrawals[j];
              if (w['state'] == 'requested' || w['state'] == 'under_review') {
                _moveForWithdrawal(-num.parse('${w['amount']}'));
                withdrawals[j] = {...w, 'state': 'cancelled', 'cancelled_by_change': true, 'can_cancel': false};
                cancelled.add('${w['number']}');
              }
            }
            pauseUntil = '2026-10-05T10:00:00+03:00';
          }
        case 'remove':
          if (a['state'] == 'pending_review') {
            payoutAccounts.removeAt(i);
          } else if (a['state'] == 'active' && a['in_use'] == true && withdrawals.any((w) => w['can_cancel'] == true)) {
            // A withdrawal is on its way to it: removed once that finishes.
            payoutAccounts[i] = {
              ...a,
              'state': 'removing',
              'can': {'use': false, 'remove': false, 'keep': true},
            };
          } else if (a['state'] == 'active') {
            payoutAccounts.removeAt(i);
          } else {
            return error(409, 'illegal_payout_account_transition');
          }
        case 'keep':
          if (a['state'] != 'removing') return error(409, 'illegal_payout_account_transition');
          payoutAccounts[i] = {
            ...a,
            'state': 'active',
            'can': {'use': a['in_use'] != true, 'remove': true, 'keep': false},
          };
      }
      return json(200, {
        'data': _payoutView,
        if (payoutAction.group(2) == 'use') 'meta': {'cancelled_withdrawals': cancelled},
      });
    }
    if (path == '/customer/me/withdrawals/confirmations') {
      if (pendingAccount) return error(403, 'verification_required');
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      if (pauseUntil != null) {
        return json(409, {
          'message': 'paused',
          'code': 'withdrawals_paused',
          'details': {'pause_until': pauseUntil},
        });
      }
      for (final c in confirmations.values) {
        if (c['state'] == 'sent') c['state'] = 'replaced';
      }
      final id = 'c0nf0000-0000-4000-8000-00000000000${confirmations.length + 1}';
      final c = {'id': id, 'state': 'sent', 'amount': '${body['amount']}.0000', 'account_id': body['payout_account_id'], 'token': 'token-$id'};
      confirmations[id] = c;
      return json(201, {'data': _confirmation(c, withEmail: true)});
    }
    final confirmation = RegExp(r'^/customer/me/withdrawals/confirmations/([^/]+)$').firstMatch(path);
    if (confirmation != null) {
      final c = confirmations[confirmation.group(1)];
      return c == null ? error(404, 'not_found') : json(200, {'data': _confirmation(c)});
    }
    if (path == '/customer/me/withdrawals') {
      if (pendingAccount) return error(403, 'verification_required');
      if (req.method == 'GET') {
        final state = req.url.queryParameters['state'];
        final rows = withdrawals.where((w) => state == null || (state == 'open') == (w['can_cancel'] == true)).toList();
        return json(200, {
          'data': rows,
          'meta': {'per_page': 50, 'next_cursor': null},
        });
      }
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final c = confirmations[body['confirmation_id']];
      if (c == null || c['state'] != 'confirmed') return error(403, 'email_confirmation_required');
      final amount = num.parse('${body['amount']}');
      if (amount > num.parse('${wallet['available']}')) return error(409, 'insufficient_funds');
      c['state'] = 'used';
      _moveForWithdrawal(amount);
      final w = {
        'id': 'wd-$_withdrawalNo',
        'number': 'WD-${_withdrawalNo++}',
        'amount': amount.toStringAsFixed(4),
        'state': 'requested',
        'on_hold': false,
        'hold_message': null,
        'account': {'bank_name': 'CIB', 'number_masked': '•••• 4417'},
        'requested_at': '2026-10-03T10:05:00+03:00',
        'released_at': null,
        'value_date': null,
        'rejection_reason': null,
        'cancelled_by_change': false,
        'can_cancel': true,
      };
      withdrawals.insert(0, w);
      return json(201, {'data': w});
    }
    final withdrawalCancel = RegExp(r'^/customer/me/withdrawals/([^/]+)/cancel$').firstMatch(path);
    if (withdrawalCancel != null) {
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final i = withdrawals.indexWhere((w) => w['id'] == withdrawalCancel.group(1));
      if (i < 0) return error(404, 'not_found');
      if (withdrawals[i]['can_cancel'] != true) return error(409, 'illegal_withdrawal_transition');
      _moveForWithdrawal(-num.parse('${withdrawals[i]['amount']}'));
      withdrawals[i] = {...withdrawals[i], 'state': 'cancelled', 'can_cancel': false};
      return json(200, {'data': withdrawals[i]});
    }
    if (path == '/withdrawal-confirmations/read' || path == '/withdrawal-confirmations/confirm') {
      final c = confirmations.values.where((c) => c['token'] == body['token']).firstOrNull;
      if (c == null || c['state'] == 'replaced' || c['state'] == 'used') return error(422, 'confirmation_invalid');
      if (path.endsWith('confirm')) c['state'] = 'confirmed';
      return json(200, {
        'data': {'state': c['state'], 'amount': c['amount'], 'account_masked': 'CIB ••4417', 'expires_at': '2026-10-03T12:30:00+03:00'},
      });
    }

    // ---- backend spec 010 ----
    if (path.contains('/media/')) return http.Response.bytes(png, 200, headers: {'content-type': 'image/png', 'cache-control': 'no-store'});
    if (path == '/reference/karats') {
      return json(200, {
        'data': [
          {'code': 18, 'sort_order': 1},
          {'code': 21, 'sort_order': 2},
          {'code': 24, 'sort_order': 3},
        ],
      });
    }
    if (path == '/reference/piece-types') return json(200, {'data': pieceTypes});
    // ---- backend spec 015: today's prices and the quote (a stand-in calculator: 20% of the making charge, 14% VAT) ----
    if (path == '/reference/gold-prices') {
      return pricesAvailable ? json(200, {'data': goldPrices}) : error(409, 'price_unavailable');
    }
    if (path == '/reference/quote') {
      if (!pricesAvailable) return error(409, 'price_unavailable');
      final q = req.url.queryParameters;
      final weight = double.tryParse(q['weight_g'] ?? '') ?? 0;
      final makingPerGram = double.tryParse(q['making_per_g'] ?? '') ?? 0;
      final karat = int.tryParse(q['karat'] ?? '') ?? 21;
      final rate = double.parse(((goldPrices['karats'] as List).firstWhere((k) => k['code'] == karat) as Map)['sellers_get'] as String);
      final gold = rate * weight;
      final making = makingPerGram * weight;
      final commission = (making * 0.2).clamp(200, double.infinity);
      final vat = commission * 0.14;
      return json(200, {
        'data': {
          'category': q['category'],
          'rate_per_gram': rate.toStringAsFixed(4),
          'gold_value': gold.toStringAsFixed(4),
          'making_back': making.toStringAsFixed(4),
          'asking_price': null,
          'commission': commission.toStringAsFixed(4),
          'vat': vat.toStringAsFixed(4),
          'payout': (gold + making - commission - vat).toStringAsFixed(4),
          'commission_rate': '20.0000',
          'minimum_applied': making * 0.2 < 200,
          'indicative': true,
          'price_at': goldPrices['price_at'],
        },
      });
    }
    if (path == '/reference/branches') return json(200, {'data': branches});
    if (path == '/reference/legal-documents/ownership_declaration') return json(200, {'data': declaration});
    if (path == '/reference/legal-documents/deposit_agreement') return json(200, {'data': depositTerms});
    if (path == '/reference/legal-documents/collection_proxy_authorisation') return json(200, {'data': proxyAuthorisation});

    // ---- backend spec 011 ----
    if (path == '/customer/me/buy-requests') {
      if (pendingAccount) return error(403, 'verification_required');
      if (req.method == 'GET') {
        final listingId = req.url.queryParameters['listing_id'];
        final state = req.url.queryParameters['state'];
        final rows = buyRequests.where((r) => (listingId == null || (r['listing'] as Map)['id'] == listingId) && (state == null || r['state'] == state));
        return json(200, {
          'data': rows.toList(),
          'meta': {'per_page': 100, 'next_cursor': null},
        });
      }
      if (suspendedReason != null) return error(403, 'account_suspended');
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      if (body['deposit_legal_doc_id'] != depositTerms['id']) return error(422, 'deposit_agreement_required');
      final row = market.where((m) => m['id'] == body['listing_id']).firstOrNull;
      if (row == null) return error(404, 'not_found');
      if (body['confirm_locked_price'] != row['current_price']) {
        return json(409, {
          'message': 'price_moved',
          'code': 'price_moved',
          'details': {'current_price': row['current_price'], 'deposit_amount': '11640.0000'},
        });
      }
      final available = double.parse('${wallet['available']}');
      if (available < 11640) {
        return json(409, {
          'message': 'insufficient_funds',
          'code': 'insufficient_funds',
          'details': {'deposit_amount': '11640.0000', 'available': wallet['available'], 'shortfall': (11640 - available).toStringAsFixed(4)},
        });
      }
      final created = buyRequest('0199c000-0000-7000-8000-00000000000${buyRequests.length + 1}', '${body['listing_id']}', 'queued', place: 2, ahead: 1);
      buyRequests.insert(0, created);
      return json(201, {'data': created});
    }
    final leave = RegExp(r'^/customer/me/buy-requests/([^/]+)/withdraw$').firstMatch(path);
    if (leave != null) {
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final i = buyRequests.indexWhere((r) => r['id'] == leave.group(1));
      if (i < 0) return error(404, 'not_found');
      if (buyRequests[i]['state'] != 'queued') return error(409, 'not_in_queue');
      buyRequests[i] = {...buyRequests[i], 'state': 'withdrawn_by_buyer', 'place_in_line': null, 'ahead_count': null, 'notify_when_free': body['notify_when_free'] == true};
      return json(200, {'data': buyRequests[i]});
    }
    final line = RegExp(r'^/customer/me/listings/([^/]+)/(buy-requests|accept|decline)$').firstMatch(path);
    if (line != null) {
      final listingId = line.group(1)!;
      final items = queues[listingId] ?? [];
      if (line.group(2) == 'buy-requests') {
        return json(200, {
          'data': items,
          'meta': {'queue_count': items.length, 'you_would_receive': '52110.0000', 'price_is_indicative': true},
        });
      }
      if (suspendedReason != null) return error(403, 'account_suspended');
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      if (items.isEmpty) return error(409, 'queue_empty');
      if (items.first['id'] != body['buy_request_id']) return error(409, 'not_queue_head');
      final i = listings.indexWhere((l) => l['id'] == listingId);
      if (line.group(2) == 'decline') {
        items.removeAt(0);
        if (items.isNotEmpty) items[0] = {...items[0], 'is_head': true, 'place_in_line': 1};
        if (i >= 0) listings[i] = {...listings[i], 'state': items.isEmpty ? 'live' : 'reserved', 'queue_count': items.length};
        return json(200, {'data': listings[i]});
      }
      if (body['branch_id'] != 1) return error(409, 'branch_not_in_options');
      final order = {
        'order_ref': 'DH-2026-000001',
        'state': 'awaiting_delivery',
        'branch': branches.first,
        'accepted_at': '2026-10-01T16:00:00+03:00',
        'reach_branch_deadline': '2026-10-05T12:00:00+03:00',
        'locked_total_price': items.first['locked_total_price'],
        'cancelled_at': null,
        'cancel_reason': null,
      };
      queues[listingId] = [];
      listings[i] = {...listings[i], 'state': 'accepted', 'queue_count': 0, 'order': order, 'can_withdraw': false};
      return json(201, {
        'data': {'order': order, 'listing': listings[i], 'released_count': items.length - 1},
      });
    }
    // ---- backend spec 012 ----
    if (path == '/customer/me/orders') {
      if (pendingAccount) return error(403, 'verification_required');
      return json(200, {
        'data': [for (final o in orders) orderOut(o)],
        'meta': {'per_page': 100, 'next_cursor': null},
      });
    }
    final ord = RegExp(r'^/customer/me/orders/([^/]+)(?:/(cancel|decision|pay-balance|relist|disputes|extension-requests|proxy/remove|proxy))?$').firstMatch(path);
    if (ord != null) {
      final i = orders.indexWhere((o) => o['id'] == ord.group(1));
      if (i < 0) return error(404, 'not_found');
      final o = orders[i];
      final action = ord.group(2);
      if (action == null) return json(200, {'data': orderOut(o, detail: true)});
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      final may = action == 'proxy/remove'
          ? o['proxy'] != null
          : (o['actions'] as List).contains(switch (action) {
              'decision' => 'decide',
              'pay-balance' => 'pay',
              'disputes' => 'report_problem',
              'extension-requests' => 'ask_more_time',
              'proxy' => 'name_proxy',
              _ => action,
            });
      if (!may) {
        if (action == 'disputes' && o['dispute'] != null) return error(409, 'dispute_already_raised');
        if (action == 'extension-requests' && (o['extension_request'] as Map?)?['state'] == 'waiting') return error(409, 'extension_request_pending');
        return error(409, action == 'relist' ? 'illegal_listing_transition' : 'illegal_order_transition');
      }
      // Spec 014: the same shapes and refusals as the backend's requests.
      if (action == 'disputes') {
        final detail = '${body['detail'] ?? ''}';
        if ('${body['reason'] ?? ''}'.isEmpty || detail.length < 10) {
          return json(422, {
            'message': 'The given data was invalid.',
            'code': 'validation_failed',
            'errors': {
              'detail': ['Too short.'],
            },
          });
        }
        final dispute = {
          'ref': 'DSP-${_disputeNo++}',
          'order_ref': o['order_ref'],
          'raised_as': o['role'],
          'reason': body['reason'],
          'detail': detail,
          'photo_count': (body['photo_tokens'] as List?)?.length ?? 0,
          'state': 'open',
          'outcome': null,
          'reply': null,
          'opened_at': '2026-10-02T11:00:00+03:00',
          'resolved_at': null,
        };
        orders[i] = {
          ...o,
          'state': 'disputed',
          'stage': 'at_igi',
          'frozen': true,
          'dispute': dispute,
          'deadline': null,
          'actions': [
            for (final a in o['actions'] as List)
              if (a != 'report_problem' && a != 'pay' && a != 'name_proxy') a,
          ],
        };
        return json(201, {'data': dispute});
      }
      switch (action) {
        case 'extension-requests':
          if ('${body['detail'] ?? ''}'.length < 10) {
            return json(422, {
              'message': 'The given data was invalid.',
              'code': 'validation_failed',
              'errors': {
                'detail': ['Too short.'],
              },
            });
          }
          orders[i] = {
            ...o,
            'actions': [
              for (final a in o['actions'] as List)
                if (a != 'ask_more_time') a,
            ],
            'extension_request': {
              'state': 'waiting',
              'reason': body['reason'],
              'detail': body['detail'],
              'hours_granted': null,
              'answer_note': null,
              'requested_at': '2026-10-02T11:00:00+03:00',
              'answered_at': null,
            },
          };
          return json(201, {'data': orderOut(orders[i], detail: true)});
        case 'proxy':
          if (body['authorisation_id'] != proxyAuthorisation['id'] || body['authorisation_accepted'] != true) return error(422, 'declaration_required');
          if (!'${body['id_upload_token']}'.startsWith('proxy_id-token-')) return error(422, 'upload_token_invalid');
          if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch('${body['phone']}')) {
            return json(422, {
              'message': 'The given data was invalid.',
              'code': 'validation_failed',
              'errors': {
                'phone': ['Invalid.'],
              },
            });
          }
          final phone = '${body['phone']}';
          orders[i] = {
            ...o,
            'proxy': {'name': body['name'], 'phone_masked': '${phone.substring(0, 4)}•••••${phone.substring(phone.length - 3)}', 'named_at': '2026-10-02T11:00:00+03:00'},
          };
          return json(200, {'data': orderOut(orders[i], detail: true)});
        case 'proxy/remove':
          orders[i] = {...o, 'proxy': null};
          return json(200, {'data': orderOut(orders[i], detail: true)});
      }
      switch (action) {
        case 'cancel':
          orders[i] = {
            ...o,
            'state': 'cancelled_seller',
            'stage': 'cancelled',
            'actions': <String>[],
            'deadline': null,
            'cancel': {'state': 'cancelled_seller', 'at': '2026-10-02T10:00:00+03:00', 'reason_kind': 'seller'},
          };
        case 'decision':
          if (body['inspection_id'] != (o['inspection'] as Map)['inspection_id']) return error(409, 'inspection_correction_not_allowed');
          orders[i] = body['accept'] == true
              ? {
                  ...o,
                  'state': 'awaiting_balance',
                  'stage': 'pay',
                  'actions': ['pay'],
                  'amount_due': '43244.0000',
                  'final_total': '54884.0000',
                  'deadline': {'kind': 'balance', 'at': '2026-10-05T10:00:00+03:00', 'overdue': false},
                }
              : {
                  ...o,
                  'state': 'cancelled_inspection',
                  'stage': 'cancelled',
                  'actions': <String>[],
                  'deadline': null,
                  'cancel': {'state': 'cancelled_inspection', 'at': '2026-10-02T10:00:00+03:00', 'reason_kind': 'declined'},
                };
        case 'pay-balance':
          final due = double.parse('${o['amount_due']}');
          final available = double.parse('${wallet['available']}');
          if (available < due) {
            return json(409, {
              'message': 'insufficient_funds',
              'code': 'insufficient_funds',
              'details': {'amount_due': o['amount_due'], 'available': wallet['available'], 'shortfall': (due - available).toStringAsFixed(4)},
            });
          }
          wallet = {...wallet, 'available': (available - due).toStringAsFixed(4)};
          orders[i] = {
            ...o,
            'state': 'ready_to_collect',
            'stage': 'collect',
            'actions': <String>[],
            'amount_due': null,
            'deadline': {'kind': 'collect', 'at': '2026-10-23T10:00:00+03:00', 'overdue': false},
            'collection': {'code_available': true, 'collect_deadline': '2026-10-23T10:00:00+03:00', 'collected_at': null, 'window_passed': false},
            '_collection_code': '482913',
          };
        case 'relist':
          orders[i] = {
            ...o,
            'actions': <String>[],
            '_return_code': null,
            'seller_return': {...(o['seller_return'] as Map), 'code_available': false, 'can_relist': false, 'relisted_at': '2026-10-02T10:00:00+03:00'},
          };
      }
      return json(200, {'data': orderOut(orders[i], detail: true)});
    }

    if (path == '/market/listings') {
      return json(200, {
        'data': market,
        'meta': {'per_page': 100, 'next_cursor': null},
      });
    }
    final marketOne = RegExp(r'^/market/listings/([^/]+)$').firstMatch(path);
    if (marketOne != null) {
      final row = market.where((m) => m['id'] == marketOne.group(1)).firstOrNull;
      if (row == null) return error(404, 'not_found');
      return json(200, {
        'data': {
          ...row,
          'description': 'Worn a few times and kept in its box. Small scratch on the inner band.',
          'video': _media('/api/v1/market/listings/${row['id']}', 'vid-${row['id']}', 'video'),
          'stone_certificate': null,
          'price_parts': {'rate_per_gram': '6975.0000', 'gold_value': '55800.0000', 'making_total': '2000.0000'},
          'deposit_amount': '11640.0000',
        },
      });
    }
    if (path == '/customer/me/listings') {
      if (pendingAccount) return error(403, 'verification_required');
      if (req.method == 'GET') {
        return json(200, {
          'data': listings,
          'meta': {'per_page': 50, 'next_cursor': null},
        });
      }
      if (suspendedReason != null) return error(403, 'account_suspended');
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      if ((body['branch_option_ids'] as List? ?? const []).isEmpty) return error(422, 'branch_options_required');
      if (body['ownership_declaration_accepted'] != true) return error(422, 'ownership_declaration_required');
      final id = '0199b000-0000-7000-8000-00000000000${_listingNo++}';
      final created = {
        ...listing(id, 'draft', photos: (body['photo_tokens'] as List? ?? const []).length, weight: '${body['stated_weight_g']}00', making: '${body['making_charge_per_g']}.0000'),
        'description': body['description'],
      };
      listings.insert(0, created);
      return json(201, {'data': created});
    }
    final mine = RegExp(r'^/customer/me/listings/([^/]+)(?:/(submit|withdraw))?$').firstMatch(path);
    if (mine != null) {
      final i = listings.indexWhere((l) => l['id'] == mine.group(1));
      if (i < 0) return error(404, 'not_found');
      final l = listings[i];
      if (req.method == 'GET') return json(200, {'data': l});
      if (suspendedReason != null) return error(403, 'account_suspended');
      if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
      switch (mine.group(2)) {
        case 'submit':
          if (l['can_submit'] != true) return error(409, 'illegal_listing_transition');
          listings[i] = _moved(l, 'in_review');
        case 'withdraw':
          if (l['state'] != 'live') return error(409, 'illegal_listing_transition');
          listings[i] = _moved(l, 'withdrawn');
        default:
          if (l['can_edit'] != true) return error(409, 'listing_not_editable');
          listings[i] = {...l, if (body.containsKey('description')) 'description': body['description']};
      }
      return json(200, {'data': listings[i]});
    }

    switch (path) {
      case '/customer/me/wallet/topup-methods':
        // Like the real API: no session, no methods.
        if (req.headers['Authorization'] == null) return error(401, 'unauthenticated');
        final refused = tradeRefusal();
        if (refused != null) return error(403, refused);
        return json(200, {'data': topUpMethods});
      case '/customer/me/uploads':
        final refused = tradeRefusal();
        if (refused != null) return error(403, refused);
        final purpose = RegExp(r'name="purpose"\s+([a-z_]+)').firstMatch(latin1.decode(req.bodyBytes))?.group(1) ?? 'topup_receipt';
        uploads.add(purpose);
        return json(201, {
          'data': {'upload_token': purpose == 'topup_receipt' ? 'receipt-token-1' : '$purpose-token-${uploads.length}', 'purpose': purpose, 'expires_in': 3600},
        });
      case '/customer/me/wallet/topups':
        if (req.method == 'GET') {
          if (pendingAccount) return error(403, 'verification_required');
          return json(200, {
            'data': topUps,
            'meta': {'per_page': 50, 'next_cursor': null},
          });
        }
        final refused = tradeRefusal();
        if (refused != null) return error(403, refused);
        if (req.headers['Idempotency-Key'] == null) return error(400, 'idempotency_key_required');
        final account = (topUpMethods['methods'] as List)
            .expand((m) => (m as Map)['accounts'] as List)
            .cast<Map>()
            .firstWhere((a) => a['id'] == body['receiving_account_id'], orElse: () => const {});
        if (account.isEmpty) {
          return json(422, {
            'message': 'bad',
            'code': 'validation_failed',
            'errors': {
              'receiving_account_id': ['The selected receiving account id is invalid.'],
            },
          });
        }
        // Backend spec 009: the display-only estimate after the account's provider fee.
        final claim = num.parse('${body['amount']}');
        final pct = account['provider_fee_percent'] == null ? 0 : num.parse('${account['provider_fee_percent']}');
        final expected = pct > 0 ? (claim - (claim * pct / 100 * 100).round() / 100).toStringAsFixed(4) : null;
        final topUp = {
          'id': 'tu-$_topUpNo',
          'number': 'TOP-${_topUpNo++}',
          'method': account['method'],
          'reference': 'DAHAB-396233',
          'status': 'pending',
          'claimed_amount': '${body['amount']}.0000',
          'expected_amount': expected,
          'credited_amount': null,
          'has_receipt': body['receipt_upload_token'] != null,
          'submitted_at': '2026-09-29T10:04:00+03:00',
          'credited_at': null,
          'reject_reason': null,
          'can_cancel': true,
        };
        topUps.insert(0, topUp);
        return json(201, {'data': topUp});
      case '/customer/auth/login':
        if (body['password'] != 'Password-1234') return error(401, 'invalid_credentials');
        if (refuseLoginWith != null) return error(403, refuseLoginWith!);
        return json(200, {'data': challenge});
      case '/customer/auth/otp/verify':
        if (body['code'] != '123456') return error(401, 'otp_invalid');
        return json(200, {
          'data': {'customer': _customer, 'session': session},
        });
      case '/customer/auth/otp/resend':
        return json(200, {'data': challenge});
      case '/customer/auth/me':
        return json(200, {'data': _customer});
      case '/customer/auth/logout':
        return http.Response('', 204);
      case '/customer/auth/logout-all':
        loggedOutEverywhere = true;
        return http.Response('', 204);
      case '/customer/me/wallet':
        if (pendingAccount) return error(403, 'verification_required');
        return json(200, {'data': wallet});
      case '/customer/me/wallet/held':
        if (pendingAccount) return error(403, 'verification_required');
        return json(200, {'data': held});
      case '/customer/me/wallet/transactions':
        if (pendingAccount) return error(403, 'verification_required');
        return json(200, {
          'data': walletRows,
          'meta': {'per_page': 100, 'next_cursor': null},
        });
      case '/customer/auth/register/start':
        if ((body['password'] as String).length < 10) {
          return json(422, {
            'message': 'bad',
            'code': 'validation_failed',
            'errors': {
              'password': ['The password field must be at least 10 characters.'],
            },
          });
        }
        return json(202, {
          'data': {'registration_ref': 'ref-1', 'status': 'phone_otp_sent'},
        });
      case '/customer/auth/register/verify-phone-otp':
      case '/customer/auth/register/verify-email-otp':
        if (body['otp'] != '123456') return error(401, 'otp_invalid');
        return json(200, {
          'data': {'registration_ref': 'ref-1'},
        });
      case '/customer/auth/register/email':
        return json(202, {
          'data': {'registration_ref': 'ref-1', 'status': 'email_otp_sent'},
        });
      case '/customer/auth/register/documents':
        return json(200, {
          'data': {'registration_ref': 'ref-1', 'status': 'document_uploaded'},
        });
      case '/customer/auth/register/submit':
        return json(202, {
          'data': {
            'customer': {...customer, 'status': 'pending_verification', 'is_verified': false},
            'status': 'pending_verification',
          },
        });
    }
    return error(404, 'not_found');
  });
}

/// Hands the sell flow a small file instead of opening a file dialog.
class FakeMediaPicker implements MediaPicker {
  final picked = <MediaKind>[];

  @override
  Future<PickedMedia?> pick(MediaKind kind) async {
    picked.add(kind);
    return PickedMedia.file(UploadFile(field: 'file', filename: '${kind.name}-${picked.length}.png', bytes: FakeBackend.png, contentType: 'image/png'));
  }
}

/// The app wired exactly like main.dart: mock repositories, and auth, the
/// wallet, the market and listings against [backend] (a [FakeBackend] by default).
Future<Widget> testApp(LangController lang, {FakeBackend? backend}) async {
  SharedPreferences.setMockInitialValues({});
  final tokens = await TokenStore.open();
  final client = ApiClient(tokens, httpClient: (backend ?? FakeBackend()).client, baseUrl: 'http://api.test/api/v1');
  final auth = AuthController(api: AuthApi(client), tokens: tokens, client: client);
  final accountRepo = MockAccountRepository();
  final payouts = ApiPayoutRepository(client, tokens);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: lang),
      ChangeNotifierProvider.value(value: auth),
      Provider<ApiClient>.value(value: client),
      Provider<CatalogRepository>.value(value: ApiCatalogRepository(client, tokens)),
      Provider<ReferenceRepository>.value(value: ApiReferenceRepository(client)),
      Provider<ListingsRepository>.value(value: ApiListingsRepository(client, tokens)),
      Provider<MediaPicker>.value(value: FakeMediaPicker()),
      Provider<BuyRequestsRepository>.value(value: ApiBuyRequestsRepository(client, tokens)),
      Provider<OrdersRepository>.value(value: ApiOrdersRepository(client, tokens, ApiBuyRequestsRepository(client, tokens))),
      Provider<WalletRepository>.value(value: ApiWalletRepository(client, tokens)),
      Provider<PayoutRepository>.value(value: payouts),
      Provider<AccountRepository>.value(value: accountRepo),
      Provider<ContentRepository>.value(value: MockContentRepository()),
      ChangeNotifierProvider(create: (_) => AppSession()),
      ChangeNotifierProvider(create: (_) => LiveRates(api: PricesApi(client))),
      ChangeNotifierProvider(create: (_) => SellDraft()),
      ChangeNotifierProvider(create: (_) => AccountController(accountRepo)),
      ChangeNotifierProvider(create: (_) => PayoutController(payouts)),
    ],
    child: const DahabApp(),
  );
}
