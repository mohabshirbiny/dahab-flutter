import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/i18n/i18n.dart';
import 'services/account_controller.dart';
import 'services/api/api_client.dart';
import 'services/api/buy_requests_api.dart';
import 'services/api/listings_api.dart';
import 'services/api/market_api.dart';
import 'services/api/orders_api.dart';
import 'services/api/payout_api.dart';
import 'services/api/prices_api.dart';
import 'services/api/token_store.dart';
import 'services/api/wallet_api.dart';
import 'services/app_session.dart';
import 'services/auth/auth_api.dart';
import 'services/auth/auth_controller.dart';
import 'services/live_rates.dart';
import 'services/media_picker.dart';
import 'services/mock_repositories.dart';
import 'services/payout_controller.dart';
import 'services/repositories.dart';
import 'services/sell_draft.dart';

/// Dahab customer app (Flutter Web).
///
/// Sign-in, registration, the wallet, the market and the seller's listings talk
/// to the real backend (`AppConfig.apiBaseUrl`, set with
/// `--dart-define=API_BASE_URL=…`). Everything else still runs on the mock
/// repositories below until the matching APIs exist; replace each Mock* with
/// an implementation of the same interface to go live.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final lang = await LangController.load();
  final tokens = await TokenStore.open();
  final client = ApiClient(tokens);
  final auth = AuthController(api: AuthApi(client), tokens: tokens, client: client);
  await auth.restore();
  final accountRepo = MockAccountRepository();
  final buyRequests = ApiBuyRequestsRepository(client, tokens);
  final payouts = ApiPayoutRepository(client, tokens);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: lang),
        ChangeNotifierProvider.value(value: auth),
        Provider<ApiClient>.value(value: client),
        // Backend spec 010: the market, the sell flow and My listings are live.
        Provider<CatalogRepository>.value(value: ApiCatalogRepository(client, tokens)),
        Provider<ReferenceRepository>.value(value: ApiReferenceRepository(client)),
        Provider<ListingsRepository>.value(value: ApiListingsRepository(client, tokens)),
        Provider<MediaPicker>.value(value: const FilePickerMediaPicker()),
        Provider<BuyRequestsRepository>.value(value: buyRequests),
        // Backend spec 012: the order life after acceptance is live.
        Provider<OrdersRepository>.value(value: ApiOrdersRepository(client, tokens, buyRequests)),
        // Backend spec 008: the wallet and its history are live.
        Provider<WalletRepository>.value(value: ApiWalletRepository(client, tokens)),
        // Backend spec 013: payout accounts and withdrawals are live.
        Provider<PayoutRepository>.value(value: payouts),
        Provider<AccountRepository>.value(value: accountRepo),
        Provider<ContentRepository>.value(value: MockContentRepository()),
        ChangeNotifierProvider(create: (_) => AppSession()),
        // Backend spec 015: today's prices and the seller's quote are live.
        ChangeNotifierProvider(create: (_) => LiveRates(api: PricesApi(client))),
        ChangeNotifierProvider(create: (_) => SellDraft()),
        ChangeNotifierProvider(create: (_) => AccountController(accountRepo)),
        ChangeNotifierProvider(create: (_) => PayoutController(payouts)),
      ],
      child: const DahabApp(),
    ),
  );
}
