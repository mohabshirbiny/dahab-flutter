import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/wallet.dart';
import '../../models/customer.dart';
import '../../models/listing.dart';
import '../../models/order.dart';
import '../../services/app_session.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../services/payout_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import '../shared/suspended_notice.dart';
import '../wallet/wallet_screens.dart';

/// `#s-account`
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _changeContact(BuildContext context, bool phone) async {
    final ok = await ask(
      context,
      title: '${context.tr('Change your')} ${context.tr(phone ? 'phone number' : 'email address')}',
      body: phone
          ? 'We send a code to the new number and tell the old one. Withdrawals pause for 48 hours after the change.'
          : 'We send a link to the new address and tell the old one. Your email is one of the two checks on withdrawals.',
      yes: 'Continue',
    );
    if (ok && context.mounted) showToast(context, 'We sent you the code.');
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>();
    final session = context.watch<AppSession>();
    final auth = context.watch<AuthController>();
    final me = auth.customer;
    final account = context.read<AccountRepository>();
    final wallet = context.read<WalletRepository>();
    final ordersRepo = context.read<OrdersRepository>();
    final listingsRepo = context.read<ListingsRepository>();
    final payouts = context.watch<PayoutController>();
    return AppPage(
      id: R.account,
      child: AsyncView<(UserProfile, WalletSummary, List<CustomerOrder>?, List<Listing>?)>(
        load: () async {
          // Backend spec 013: the payout account in use is live.
          if (me != null) await payouts.load();
          // The Activity counts come from the live orders and listings; a failure only hides them.
          Future<V?> quiet<V>(Future<V> Function() f) async {
            try {
              return await f();
            } on Object {
              return null;
            }
          }

          final orders = me == null ? null : await quiet(ordersRepo.list);
          final listings = me == null ? null : await quiet(listingsRepo.mine);
          return (await account.profile(), await wallet.summary(), orders, listings);
        },
        loadingHeight: 400,
        builder: (context, data) {
          final (mock, summary, orders, listings) = data;
          // Identity comes from the signed-in customer (`/customer/auth/me`);
          // the wallet and the payout account are live; activity stays on mock data.
          final p = me == null ? mock : _profileFrom(me, mock);
          final inUse = payouts.view?.inUse;
          final payoutShort = me == null ? p.payoutShort : (inUse?.short ?? context.t(payouts.view == null ? '' : 'Add one'));
          final idVerified = me?.isVerified ?? true;
          // A rejected customer can sign in and send new ID photos (backend spec 002).
          final idRejected = me?.status == 'rejected';
          final emailConfirmed = me == null || me.emailVerifiedAt != null;
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
                          decoration: const BoxDecoration(color: DColors.paper, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            p.initial,
                            style: const TextStyle(fontFamily: DFonts.serif, fontSize: 22, color: DColors.gold),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              T(p.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              T('${p.sellerId}, member since ${p.memberSince}', style: DText.tiny),
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
                        idVerified
                            ? const DPill('Identity verified', icon: 'circle-check')
                            : idRejected
                            ? const DPill('ID not approved', kind: PillKind.bad)
                            : const DPill('Waiting for verification', kind: PillKind.wait),
                        const DPill('Phone confirmed'),
                        if (emailConfirmed) const DPill('Email confirmed'),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(14),
              BalanceCard(summary: summary, onOpen: () => context.nav(R.wallet), showHint: true),
              const Gap(14),
              const DLabel('Your details'),
              // Signed out, these details are the prototype's sample customer.
              MockMark(
                enabled: me == null,
                child: DCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      DRow(
                        'Phone',
                        p.phoneMasked,
                        keyWidget: const _MockKey('Phone'),
                        padding: detailPad,
                        bottomBorder: true,
                        valueWidget: chevronValue(p.phoneMasked),
                        onTap: () => _changeContact(context, true),
                      ),
                      DRow(
                        'Email',
                        p.email,
                        keyWidget: const _MockKey('Email'),
                        padding: detailPad,
                        bottomBorder: true,
                        valueWidget: chevronValue(p.email),
                        onTap: () => _changeContact(context, false),
                      ),
                      DRow(
                        'National ID',
                        '',
                        padding: detailPad,
                        bottomBorder: true,
                        valueWidget: idVerified ? const DPill('Verified') : const DPill('Waiting', kind: PillKind.wait),
                      ),
                      DRow('Payout account', payoutShort, padding: detailPad, valueWidget: chevronValue(payoutShort), onTap: () => context.nav(R.bank)),
                    ],
                  ),
                ),
              ),
              const Gap(14),
              const DNote(
                icon: 'shield-lock',
                text: 'Money can only be withdrawn to a bank account in your own name. Changing that account takes a manual check and a short wait.',
              ),
              const Gap(16),
              const DLabel('Activity'),
              DMenuCard(
                children: [
                  DMenu(icon: 'clipboard-list', title: 'Orders', sub: _ordersSub(orders), onTap: () => context.nav(R.orders)),
                  DMenu(icon: 'receipt-2', title: 'Transactions and invoices', sub: 'Tax invoices for what you sold and bought', onTap: () => context.nav(R.invoices)),
                  DMenu(icon: 'users', title: 'Invite a friend', sub: 'Both of you pay less commission', onTap: () => context.nav(R.invite), mock: true),
                  DMenu(icon: 'heart', title: 'Saved pieces', sub: '6 saved', onTap: () => context.nav(R.saved), mock: true),
                  DMenu(icon: 'tag', title: 'My listings', sub: _listingsSub(listings), onTap: () => context.nav(R.listings)),
                ],
              ),
              const Gap(14),
              const DLabel('Settings'),
              DMenuCard(
                children: [
                  DMenu(icon: 'lock', title: 'Password and devices', onTap: () => context.nav(R.security)),
                  DMenu(
                    icon: 'language',
                    title: 'Language',
                    subWidget: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(lang.isArabic ? 'العربية' : 'English', style: const TextStyle(fontSize: 11, color: DColors.ink3)),
                    ),
                    onTap: lang.toggle,
                  ),
                  DMenu(icon: 'tag', title: 'Promo codes', sub: 'Admin only, tied to one account each', onTap: () => context.nav(R.codes), mock: true),
                  DMenu(icon: 'circle-check', title: 'Approve for market makers', sub: 'Admin only, pieces older than 7 days', onTap: () => context.nav(R.mmapprove), mock: true),
                  DMenu(icon: 'wallet', title: 'Pay compensation', sub: 'Admin only, logged with your name', onTap: () => context.nav(R.compensate), mock: true),
                  DMenu(
                    icon: 'chart-line',
                    title: 'Show payout averages',
                    sub: 'Admin only, turn on once there is enough data',
                    onTap: () {
                      session.togglePayStats();
                      showToast(context, session.payStatsVisible ? 'Averages shown.' : 'Averages hidden.');
                    },
                  ),
                  DMenu(icon: 'file-text', title: 'Terms and privacy', onTap: () => context.nav(R.legal), mock: true),
                  DMenu(icon: 'help', title: 'Help', onTap: () => context.nav(R.help), mock: true),
                  DMenu(icon: 'device-mobile', title: 'Contact us', sub: '16000, chat, WhatsApp', onTap: () => context.nav(R.support), mock: true),
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
                child: MockMark(
                  child: DLink(
                    'Close my account',
                    style: const TextStyle(fontSize: 12, color: DColors.bad),
                    onTap: () => context.nav(R.delete),
                  ),
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
    displayName: name.isEmpty ? c.phone : name.split(RegExp(r'\s+')).take(2).join(' '),
    fullName: name,
    sellerId: 'Seller ${c.displayRef}',
    memberSince: created == null ? '' : monthYear(created),
    phoneMasked: maskPhone(c.phone),
    email: c.email ?? '',
    payoutShort: '',
    inviteCode: mock.inviteCode,
  );
}

/// A details label whose change action is still mock (changing the phone or email only shows a toast).
class _MockKey extends StatelessWidget {
  const _MockKey(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: T(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: DColors.ink2),
        ),
      ),
      const SizedBox(width: 6),
      const MockFlag(),
    ],
  );
}

/// "1 selling, 2 buying" — the open orders by side; nothing when not loaded.
String? _ordersSub(List<CustomerOrder>? orders) {
  if (orders == null) return null;
  final open = [
    for (final o in orders)
      if (o.stage != CustomerOrderStage.done && o.stage != CustomerOrderStage.cancelled) o,
  ];
  if (open.isEmpty) return 'No open orders';
  final selling = open.where((o) => o.isSeller).length;
  return '$selling selling, ${open.length - selling} buying';
}

/// "2 live of 5" — listings on the market (live or with a buyer in line) out of all of them.
String? _listingsSub(List<Listing>? listings) {
  if (listings == null) return null;
  if (listings.isEmpty) return 'Nothing listed yet';
  final live = listings.where((l) => l.state == ListingState.live || l.state == ListingState.reserved).length;
  return '$live live of ${listings.length}';
}
