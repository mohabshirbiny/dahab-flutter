import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/referral.dart';
import '../../core/text/texts_controller.dart';
import '../../models/account.dart';
import '../../models/wallet.dart';
import '../../models/customer.dart';
import '../../models/listing.dart';
import '../../models/order.dart';
import '../../models/referral.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../services/payout_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/suspended_notice.dart';
import 'identity_again_screen.dart';
import '../wallet/wallet_screens.dart';

/// The *Invite a friend* entry: shown only while the backend's referral switch is on (spec 023).
class _InviteMenu extends StatefulWidget {
  const _InviteMenu();

  @override
  State<_InviteMenu> createState() => _InviteMenuState();
}

class _InviteMenuState extends State<_InviteMenu> {
  late final Future<ReferralSummary> _summary = context.read<ReferralRepository>().summary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReferralSummary>(
      future: _summary,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null || !s.enabled) return const SizedBox.shrink();
        return DMenu(
          icon: 'users',
          title: context.k(ReferralKeys.title),
          sub: context.k(ReferralKeys.menuSub),
          onTap: () => context.nav(R.invite),
        );
      },
    );
  }
}

/// `#s-account`
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  /// Backend spec 017: a code to the new number, or a link to the new address.
  void _changeContact(BuildContext context, bool phone) {
    if (!context.read<AuthController>().isSignedIn) return context.nav(R.login);
    context.nav(phone ? R.changePhone : R.changeEmail);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>();
    final auth = context.watch<AuthController>();
    final me = auth.customer;
    final account = context.read<AccountRepository>();
    final wallet = context.read<WalletRepository>();
    final ordersRepo = context.read<OrdersRepository>();
    final listingsRepo = context.read<ListingsRepository>();
    final payouts = context.watch<PayoutController>();
    // Signed out there is no account to show: a prompt, never a sample person.
    if (me == null) {
      return AppPage(
        id: R.account,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DCard(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(
                    'Sign in to see your account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Gap(6),
                  T(
                    'Your orders, your wallet and your listings are here once you sign in.',
                    style: DText.muted,
                  ),
                ],
              ),
            ),
            const Gap(14),
            DButton('Sign in', onTap: () => context.nav(R.login)),
            const Gap(9),
            DButton.ghost(
              'Create an account',
              onTap: () => context.nav(R.signup1),
            ),
          ],
        ),
      );
    }
    return AppPage(
      id: R.account,
      child: AsyncView<(UserProfile, WalletSummary, List<CustomerOrder>?, List<Listing>?)>(
        load: () async {
          // Backend spec 013: the payout account in use is live.
          await payouts.load();
          // The Activity counts come from the live orders and listings; a failure only hides them.
          Future<V?> quiet<V>(Future<V> Function() f) async {
            try {
              return await f();
            } on Object {
              return null;
            }
          }

          final orders = await quiet(ordersRepo.list);
          final listings = await quiet(listingsRepo.mine);
          return (
            await account.profile(),
            await wallet.summary(),
            orders,
            listings,
          );
        },
        loadingHeight: 400,
        builder: (context, data) {
          final (mock, summary, orders, listings) = data;
          // Identity comes from the signed-in customer (`/customer/auth/me`);
          // the wallet and the payout account are live; activity stays on mock data.
          final p = _profileFrom(me, mock);
          final inUse = payouts.view?.inUse;
          final payoutShort =
              inUse?.short ?? context.t(payouts.view == null ? '' : 'Add one');
          final idVerified = me.isVerified;
          // A rejected or asked-again customer sends new ID photos (backend testing fixes item 5).
          // A rejected one opens the same screen, which says to contact customer service.
          final canResubmit = !idVerified && (me.verification.canSubmit || me.verification.isRejected);
          final emailConfirmed = me.emailVerifiedAt != null;
          const detailPad = EdgeInsets.symmetric(vertical: 13);
          Widget chevronValue(String v) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: T(v, style: DText.body13, textAlign: TextAlign.end),
              ),
              const SizedBox(width: 4),
              const DIcon('chevron-right', size: 13, color: DColors.ink3),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend spec 007: only shown while the account is suspended.
              const SuspendedNotice(margin: EdgeInsets.only(bottom: 14)),
              DCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: DColors.paper,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.initial,
                            style: const TextStyle(
                              fontFamily: DFonts.serif,
                              fontSize: 22,
                              color: DColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              T(
                                p.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              T(
                                '${p.sellerId}, member since ${p.memberSince}',
                                style: DText.tiny,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Backend testing fixes item 4: the same state as the National ID row.
                        idVerified
                            ? const DPill(
                                'Identity verified',
                                icon: 'circle-check',
                              )
                            : IdentityPill(me),
                        const DPill('Phone confirmed'),
                        if (emailConfirmed) const DPill('Email confirmed'),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(14),
              BalanceCard(
                summary: summary,
                onOpen: () => context.nav(R.wallet),
                showHint: true,
              ),
              const Gap(14),
              const DLabel('Your details'),
              DCard(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    DRow(
                      'Phone',
                      p.phoneMasked,
                      padding: detailPad,
                      bottomBorder: true,
                      valueWidget: chevronValue(p.phoneMasked),
                      onTap: () => _changeContact(context, true),
                    ),
                    DRow(
                      'Email',
                      p.email,
                      padding: detailPad,
                      bottomBorder: true,
                      valueWidget: chevronValue(p.email),
                      onTap: () => _changeContact(context, false),
                    ),
                    // Backend testing fixes items 4–5: the real state, and the way to send the ID again.
                    DRow(
                      'National ID',
                      '',
                      padding: detailPad,
                      bottomBorder: true,
                      valueWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IdentityPill(me),
                          if (canResubmit) ...[
                            const SizedBox(width: 4),
                            const DIcon('chevron-right', size: 13, color: DColors.ink3),
                          ],
                        ],
                      ),
                      onTap: canResubmit ? () => context.nav(R.idAgain) : null,
                    ),
                    DRow(
                      'Payout account',
                      payoutShort,
                      padding: detailPad,
                      valueWidget: chevronValue(payoutShort),
                      onTap: () => context.nav(R.bank),
                    ),
                  ],
                ),
              ),
              const Gap(14),
              const DNote(
                icon: 'shield-lock',
                text:
                    'Money can only be withdrawn to a bank account in your own name. Changing that account takes a manual check and a short wait.',
              ),
              const Gap(16),
              const DLabel('Activity'),
              DMenuCard(
                children: [
                  DMenu(
                    icon: 'clipboard-list',
                    title: 'Orders',
                    sub: _ordersSub(orders),
                    onTap: () => context.nav(R.orders),
                  ),
                  DMenu(
                    icon: 'receipt-2',
                    title: 'Transactions and invoices',
                    sub: 'Tax invoices for what you sold and bought',
                    onTap: () => context.nav(R.invoices),
                  ),
                  const _InviteMenu(),
                  DMenu(
                    icon: 'heart',
                    title: 'Saved pieces',
                    sub: "Saved pieces don't lock a price",
                    onTap: () => context.nav(R.saved),
                  ),
                  DMenu(
                    icon: 'tag',
                    title: 'My listings',
                    sub: _listingsSub(listings),
                    onTap: () => context.nav(R.listings),
                  ),
                ],
              ),
              const Gap(14),
              const DLabel('Settings'),
              DMenuCard(
                children: [
                  DMenu(
                    icon: 'lock',
                    title: 'Password and devices',
                    onTap: () => context.nav(R.security),
                  ),
                  DMenu(
                    icon: 'language',
                    title: 'Language',
                    subWidget: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        lang.isArabic ? 'العربية' : 'English',
                        style: const TextStyle(
                          fontSize: 11,
                          color: DColors.ink3,
                        ),
                      ),
                    ),
                    onTap: lang.toggle,
                  ),
                  DMenu(
                    icon: 'bell',
                    title: 'Notifications',
                    onTap: () => context.nav(R.inbox),
                  ),
                  DMenu(
                    icon: 'file-text',
                    title: 'Terms and privacy',
                    onTap: () => context.nav(R.legal),
                  ),
                  DMenu(
                    icon: 'help',
                    title: 'Help',
                    onTap: () => context.nav(R.help),
                  ),
                  DMenu(
                    icon: 'device-mobile',
                    title: 'Contact us',
                    sub: 'Phone, WhatsApp or email',
                    onTap: () => context.nav(R.support),
                  ),
                ],
              ),
              const Gap(16),
              DButton.ghost(
                'Sign out',
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) context.enterApp(R.splash);
                },
              ),
              const Gap(16),
              Center(
                child: DLink(
                  'Close my account',
                  style: const TextStyle(fontSize: 12, color: DColors.bad),
                  onTap: () => context.nav(R.delete),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The prototype's profile card fed from the real customer record.
UserProfile _profileFrom(CustomerProfile c, UserProfile mock) {
  final created = c.createdAt;
  final name = (c.fullName ?? '').trim();
  return UserProfile(
    displayName: name.isEmpty
        ? c.phone
        : name.split(RegExp(r'\s+')).take(2).join(' '),
    fullName: name,
    sellerId: 'Seller ${c.displayRef}',
    memberSince: created == null ? '' : monthYear(created),
    phoneMasked: maskPhone(c.phone),
    email: c.email ?? '',
    payoutShort: '',
    inviteCode: mock.inviteCode,
  );
}

/// "1 selling, 2 buying" — the open orders by side; nothing when not loaded.
String? _ordersSub(List<CustomerOrder>? orders) {
  if (orders == null) return null;
  final open = [
    for (final o in orders)
      if (o.stage != CustomerOrderStage.done &&
          o.stage != CustomerOrderStage.cancelled)
        o,
  ];
  if (open.isEmpty) return 'No open orders';
  final selling = open.where((o) => o.isSeller).length;
  return '$selling selling, ${open.length - selling} buying';
}

/// "2 live of 5" — listings on the market (live or with a buyer in line) out of all of them.
String? _listingsSub(List<Listing>? listings) {
  if (listings == null) return null;
  if (listings.isEmpty) return 'Nothing listed yet';
  final live = listings
      .where(
        (l) => l.state == ListingState.live || l.state == ListingState.reserved,
      )
      .length;
  return '$live live of ${listings.length}';
}
