import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/account/bank_screens.dart';
import '../features/account/settings_screens.dart';
import '../features/admin/admin_screens.dart';
import '../features/auth/login_screens.dart';
import '../features/auth/signup_screens.dart';
import '../features/auth/splash_screen.dart';
import '../features/catalog/browse_screen.dart';
import '../features/catalog/buy_screens.dart';
import '../features/catalog/detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/orders/order_flows.dart';
import '../features/orders/order_help_screens.dart';
import '../features/orders/order_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/sell/sell1_screen.dart';
import '../features/sell/sell2_screen.dart';
import '../features/sell/sell3_screen.dart';
import '../features/wallet/wallet_screens.dart';
import '../features/wallet/withdraw_confirm_screen.dart';
import '../widgets/widgets.dart';

/// The prototype's Inspection, Pay and Collection-code screens are parts of the live order
/// screen (backend spec 012): `?id=` opens that order, no id opens the Orders list.
Widget _liveOrder(GoRouterState s) {
  final id = s.uri.queryParameters['id'] ?? '';
  return id.isEmpty ? const OrdersScreen() : OrderScreen(id: id);
}

/// Every screen, keyed by its prototype id.
final Map<String, Widget Function(GoRouterState s)> _screens = {
  R.splash: (_) => const SplashScreen(),
  R.login: (_) => const LoginScreen(),
  R.otp: (_) => const OtpScreen(),
  R.signup1: (_) => const Signup1Screen(),
  R.signup2: (_) => const Signup2Screen(),
  R.signup3: (_) => const Signup3Screen(),
  R.signupEmail: (_) => const SignupEmailScreen(),
  R.signupDone: (_) => const SignupDoneScreen(),
  R.home: (_) => const HomeScreen(),
  R.browse: (_) => const BrowseScreen(),
  R.detail: (s) => DetailScreen(view: parseDetailView(s.uri.queryParameters['view']), pieceId: s.uri.queryParameters['id'] ?? 'p1'),
  R.sell1: (_) => const Sell1Screen(),
  R.sell2: (_) => const Sell2Screen(),
  R.sell3: (_) => const Sell3Screen(),
  R.weight: (_) => const WeightGuideScreen(),
  R.orders: (_) => const OrdersScreen(),
  R.listings: (_) => const ListingsScreen(),
  R.editprice: (_) => const EditPriceScreen(),
  R.extend: (s) => ExtendScreen(orderId: s.uri.queryParameters['id'] ?? ''),
  R.dispute: (s) => DisputeScreen(orderId: s.uri.queryParameters['id'] ?? ''),
  R.inspection: _liveOrder,
  R.order: (s) => OrderScreen(id: s.uri.queryParameters['id'] ?? ''),
  R.branch: (_) => const BranchScreen(),
  R.pay: _liveOrder,
  R.code: _liveOrder,
  R.proxy: (s) => ProxyScreen(orderId: s.uri.queryParameters['id'] ?? ''),
  R.rate: (_) => const RateScreen(),
  R.account: (_) => const AccountScreen(),
  R.wallet: (_) => const WalletScreen(),
  R.held: (_) => const HeldScreen(),
  R.txn: (s) => TxnScreen(id: s.uri.queryParameters['id'] ?? 't1'),
  R.withdraw: (_) => const WithdrawScreen(),
  R.withdrawConfirm: (s) => WithdrawConfirmScreen(token: s.uri.queryParameters['token'] ?? ''),
  R.addfunds: (_) => const AddFundsScreen(),
  R.topups: (_) => const TopUpsScreen(),
  R.invoices: (_) => const InvoicesScreen(),
  R.invoice: (s) => InvoiceScreen(id: s.uri.queryParameters['id'] ?? ''),
  R.saved: (_) => const SavedScreen(),
  R.gate: (_) => const GateScreen(),
  R.reqsent: (_) => const RequestSentScreen(),
  R.topup: (_) => const TopUpFirstScreen(),
  R.report: (_) => const ReportListingScreen(),
  R.bank: (_) => const BankScreen(),
  R.bankadd: (_) => const BankAddScreen(),
  R.security: (_) => const SecurityScreen(),
  R.notif: (_) => const NotificationSettingsScreen(),
  R.inbox: (_) => const InboxScreen(),
  R.help: (_) => const HelpScreen(),
  R.legal: (_) => const LegalScreen(),
  R.support: (_) => const SupportScreen(),
  R.delete: (_) => const DeleteAccountScreen(),
  R.invite: (_) => const InviteScreen(),
  R.prices: (_) => const PricesScreen(),
  R.codes: (_) => const PromoCodesScreen(),
  R.codeuses: (_) => const CodeUsesScreen(),
  R.mmapprove: (_) => const MarketMakerApproveScreen(),
  R.compensate: (_) => const CompensateScreen(),
};

/// Screen ids with a route, for tests and the QA checklist.
Iterable<String> get allScreenIds => _screens.keys;

/// The prototype swaps screens instantly, so pages have no transition.
GoRouter buildRouter({bool signedIn = false}) => GoRouter(
  initialLocation: '/${signedIn ? R.home : R.splash}',
  routes: [
    GoRoute(path: '/', redirect: (_, _) => '/${signedIn ? R.home : R.splash}'),
    for (final e in _screens.entries)
      GoRoute(
        path: '/${e.key}',
        pageBuilder: (context, state) => NoTransitionPage<void>(key: state.pageKey, name: e.key, child: e.value(state)),
      ),
  ],
  errorPageBuilder: (context, state) => const NoTransitionPage<void>(child: _NotFound()),
);

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: 'notfound',
      title: 'Page not found',
      child: DEmpty(icon: 'alert-triangle', title: 'Page not found', body: 'Nothing here', action: 'Go home', onAction: () => context.enterApp(R.home)),
    );
  }
}
