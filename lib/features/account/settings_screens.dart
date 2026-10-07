import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/account.dart';
import '../../models/reference.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/inbox_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import 'account_messages.dart';

/// `#s-security` — the password and the devices signed in (backend spec 017 FR-012, FR-020).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _changing = false;
  String? _key;
  int _reload = 0;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  bool _signingOut = false;

  Future<void> _signOutEverywhere() async {
    final ok = await ask(
      context,
      title: 'Sign out of every device',
      body: 'Every phone and browser signed in to your account is signed out, this one too. You sign in again with your password and a code.',
      yes: 'Sign out everywhere',
    );
    if (!ok || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await context.read<AuthController>().logoutAll();
      if (!mounted) return;
      showToast(context, 'Signed out of every device.');
      context.nav(R.login);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.isNetwork ? 'Could not reach the server. Check your connection and try again.' : 'Something went wrong');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _change() async {
    if (_current.text.isEmpty) return setState(() => _error = 'Enter your password.');
    if (_next.text.length < 8) return setState(() => _error = 'Your password needs at least 8 characters.');
    if (_next.text == _current.text) return setState(() => _error = 'Choose a password you have not used here.');
    setState(() {
      _error = null;
      _changing = true;
    });
    try {
      _key ??= newIdempotencyKey();
      await context.read<AccountRepository>().changePassword(current: _current.text, next: _next.text, idempotencyKey: _key!);
      _key = null;
      if (!mounted) return;
      _current.clear();
      _next.clear();
      setState(() => _reload++);
      showToast(context, 'Password changed. Your other devices were signed out.');
    } on ApiException catch (e) {
      if (e.code != 'network_error') _key = null;
      if (mounted) setState(() => _error = accountErrorMessage(e));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _signOut(AccountSession s) async {
    final ok = await ask(context, title: 'Sign out of this device', body: 'It is signed out now, and it needs a code the next time someone signs in on it.', yes: 'Sign out');
    if (!ok || !mounted) return;
    try {
      await context.read<AccountRepository>().signOutSession(s.id, idempotencyKey: newIdempotencyKey());
      if (!mounted) return;
      setState(() => _reload++);
      showToast(context, 'Signed out of that device.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, accountErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AuthController>().isSignedIn;
    return AppPage(
      id: R.security,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DLabel('Password'),
          DField(
            label: 'Current password',
            child: DInput(controller: _current, password: true, hint: '••••••••'),
          ),
          DField(
            label: 'New password',
            bottom: 0,
            child: DInput(controller: _next, password: true, hint: 'At least 8 characters'),
          ),
          DError(_error ?? '', visible: _error != null),
          const Gap(13),
          DButton.ghost('Change password', loading: _changing, onTap: signedIn ? _change : null),
          const Gap(20),
          const DLabel('Devices signed in'),
          AsyncView<List<AccountSession>>(
            key: ValueKey(_reload),
            load: context.read<AccountRepository>().sessions,
            loadingHeight: 100,
            builder: (context, sessions) => sessions.isEmpty
                ? const T('No device is signed in.', style: DText.tiny)
                : DMenuCard(
                    children: [
                      for (final s in sessions)
                        DMenu(
                          icon: 'device-mobile',
                          title: s.name,
                          sub: s.current
                              ? context.t('This device, now')
                              : s.lastActiveAt == null
                              ? null
                              : '${context.t('Last used')} ${whenOf(s.lastActiveAt!)}',
                          trailing: s.current
                              ? const DPill('Current')
                              : DLink(
                                  'Sign out',
                                  style: const TextStyle(fontSize: 12, color: DColors.bad),
                                  onTap: () => _signOut(s),
                                ),
                        ),
                    ],
                  ),
          ),
          if (signedIn) ...[const Gap(12), DButton.ghost('Sign out of every device', loading: _signingOut, foreground: DColors.bad, onTap: _signOutEverywhere)],
          const Gap(14),
          const DNote(
            icon: 'shield-lock',
            text: 'Every withdrawal is checked by a person before it leaves. If someone signs in from a new device, we tell you on your number and email.',
          ),
        ],
      ),
    );
  }
}

/// `#s-notif` — what Dahab tells you (backend spec 017 FR-033). Nothing here can be
/// switched off yet: requests, deadlines, security and money are always on.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.notif,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DMenuCard(
            children: [
              for (final (title, sub) in const [
                ('A buyer requests my piece', 'Always on, this one has a deadline'),
                ('Deadline reminders', 'Always on, money depends on them'),
                ('Security and money', 'Always on: sign-ins, contact changes, your wallet'),
              ])
                DMenu(title: title, sub: sub, trailing: const DPill('On')),
            ],
          ),
          const Gap(14),
          const T('We send these by SMS, by email when you have one, and here in the app. Deadline and request alerts stay on because money depends on them.', style: DText.tiny),
        ],
      ),
    );
  }
}

/// `#s-inbox` — every message Dahab sent you (backend spec 017 FR-030–FR-032).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _items = <InboxItem>[];
  String? _cursor;
  bool _loading = true;
  bool _more = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await context.read<AccountRepository>().inbox(cursor: next ? _cursor : null);
      if (!mounted) return;
      setState(() {
        if (!next) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _more = page.nextCursor != null;
      });
      context.read<InboxController>().set(page.unread);
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(InboxItem n) async {
    if (n.unread) {
      try {
        await context.read<AccountRepository>().markRead(n.id, idempotencyKey: newIdempotencyKey());
        if (!mounted) return;
        final i = _items.indexOf(n);
        if (i >= 0) setState(() => _items[i] = InboxItem.fromJson(_asRead(n)));
        context.read<InboxController>().refresh(force: true);
      } on ApiException {
        // Reading it is enough; the next visit tries again.
      }
    }
    if (!mounted) return;
    final id = n.linkId;
    switch (n.linkKind) {
      case 'order':
        if (id != null) context.nav(R.order, query: {'id': id});
      case 'listing':
        if (id != null) context.openPiece(id: id);
      case 'invoice':
        if (id != null) context.nav(R.invoice, query: {'id': id});
      case 'credit_note':
        context.nav(R.invoices);
      case 'wallet' || 'withdrawal':
        context.nav(R.wallet);
      case 'topup':
        context.nav(R.topups);
      case 'payout_account':
        context.nav(R.bank);
      case 'dispute' || 'buy_request':
        context.nav(R.orders);
      case 'account':
        context.nav(R.account);
    }
  }

  static Map<String, dynamic> _asRead(InboxItem n) => {
    'id': n.id,
    'type': n.type,
    'link': {'kind': n.linkKind, 'id': n.linkId},
    'title_en': n.titleEn,
    'title_ar': n.titleAr,
    'body_en': n.bodyEn,
    'body_ar': n.bodyAr,
    'created_at': n.createdAt?.toIso8601String(),
    'read_at': DateTime.now().toIso8601String(),
  };

  Future<void> _readAll() async {
    try {
      await context.read<AccountRepository>().markAllRead(idempotencyKey: newIdempotencyKey());
      if (!mounted) return;
      context.read<InboxController>().set(0);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, accountErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LangController>().isArabic;
    final Widget list;
    if (_failed && _items.isEmpty) {
      list = DErrorState(onRetry: _load);
    } else if (_loading && _items.isEmpty) {
      list = const DLoading(height: 300);
    } else if (_items.isEmpty) {
      list = const DEmpty(icon: 'bell', title: 'No notifications yet', body: 'Nothing here yet');
    } else {
      list = DMenuCard(
        children: [
          for (final n in _items)
            DMenu(
              title: n.title(arabic),
              icon: n.unread ? 'bell' : 'circle-check',
              iconColor: n.unread ? DColors.gold : DColors.ink3,
              titleWidget: Text(n.title(arabic), style: TextStyle(fontSize: 14, fontWeight: n.unread ? FontWeight.w600 : FontWeight.w400)),
              subWidget: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  n.createdAt == null ? n.body(arabic) : '${n.body(arabic)} · ${whenOf(n.createdAt!)}',
                  style: const TextStyle(fontSize: 11, color: DColors.ink3, height: 1.5),
                ),
              ),
              onTap: () => _open(n),
            ),
        ],
      );
    }
    return AppPage(
      id: R.inbox,
      child: Column(
        children: [
          if (_items.any((n) => n.unread)) ...[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DLink('Mark all as read', style: DText.link12, onTap: _readAll),
            ),
            const Gap(10),
          ],
          list,
          if (_more) ...[const Gap(12), DButton.ghost('Load more', loading: _loading, onTap: () => _load(next: true))],
          const Gap(14),
          DButton.ghost('Notification settings', onTap: () => context.nav(R.notif)),
        ],
      ),
    );
  }
}

/// `#s-help` — FAQ with expanding answers.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _open = <int>{};

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.help,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DLabel('The ones people ask most'),
          AsyncView<List<FaqItem>>(
            load: context.read<ContentRepository>().faq,
            builder: (context, faq) => DMenuCard(
              children: [
                for (var i = 0; i < faq.length; i++)
                  _FaqRow(item: faq[i], open: _open.contains(i), onTap: () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i))),
              ],
            ),
          ),
          const Gap(14),
          const DLabel('Still stuck'),
          DMenuCard(
            children: [DMenu(icon: 'device-mobile', title: 'Contact us', sub: '16000, chat, WhatsApp or email', onTap: () => context.nav(R.support))],
          ),
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.item, required this.open, required this.onTap});

  final FaqItem item;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Semantics(
        expanded: open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(item.question, style: DText.body14),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      alignment: AlignmentDirectional.topStart,
                      child: open
                          ? Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: T(item.answer, style: const TextStyle(fontSize: 12, color: DColors.ink2, height: 1.75)),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              open ? const DIcon('circle-check', size: 16, color: DColors.gold) : const DIcon('chevron-right', size: 16, color: DColors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

/// `#s-legal` — the documents the backend lists (spec 017 FR-045); only published ones open.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.legal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AsyncView<List<LegalEntry>>(
            load: context.read<AccountRepository>().legalDocuments,
            builder: (context, docs) => DMenuCard(
              children: [
                for (final d in docs)
                  DMenu(
                    title: d.title,
                    sub: d.published ? null : context.t('Not published yet'),
                    onTap: d.published ? () => context.nav(R.legalDoc, query: {'code': d.code}) : () => showToast(context, 'This document is not published yet.'),
                  ),
              ],
            ),
          ),
          const Gap(14),
          const T('Dahab acts as an intermediary between buyer and seller. The full terms explain what that means for each side.', style: DText.tiny),
        ],
      ),
    );
  }
}

/// `#/legal-doc?code=` — one published legal document, in the app's language.
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LangController>().isArabic;
    return AppPage(
      id: R.legalDoc,
      title: LegalEntry(code: code, published: true).title,
      child: AsyncView<LegalDoc>(
        load: () => context.read<AccountRepository>().legalDocument(code),
        builder: (context, doc) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            T('${context.t('Version')} ${doc.version}', style: DText.tiny),
            const Gap(10),
            Text(arabic ? doc.bodyAr : doc.bodyEn, style: const TextStyle(fontSize: 13, height: 1.75, color: DColors.ink2)),
          ],
        ),
      ),
    );
  }
}

/// `#s-support` — how to reach Dahab, from the backend (`/reference/support-contacts`).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arabic = context.watch<LangController>().isArabic;
    return AppPage(
      id: R.support,
      child: AsyncView<SupportContacts>(
        load: context.read<AccountRepository>().supportContacts,
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DLabel('Talk to us', bottom: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: DIcon('device-mobile', size: 19, color: DColors.gold),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.phone, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            Text(arabic ? c.hoursAr : c.hoursEn, style: DText.tiny),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(14),
            DMenuCard(
              children: [
                if (c.whatsapp.isNotEmpty) DMenu(icon: 'device-mobile', title: 'WhatsApp', sub: c.whatsapp),
                if (c.email.isNotEmpty) DMenu(icon: 'mail', title: 'Email us', sub: c.email),
              ],
            ),
            if (c.social.isNotEmpty) ...[
              const Gap(14),
              const DLabel('Follow Dahab'),
              DMenuCard(
                children: [
                  for (final MapEntry(:key, :value) in c.social.entries)
                    DMenu(
                      icon: switch (key) {
                        'instagram' => 'camera',
                        'tiktok' => 'video',
                        _ => 'users',
                      },
                      title: switch (key) {
                        'facebook' => 'Facebook',
                        'instagram' => 'Instagram',
                        'tiktok' => 'TikTok',
                        _ => key,
                      },
                      sub: '@$value',
                    ),
                ],
              ),
            ],
            const Gap(16),
            const DNote(icon: 'shield-lock', text: 'Dahab will never ask for your password or your code, on any channel. If someone does, it is not us.'),
          ],
        ),
      ),
    );
  }
}

/// `#s-delete` — close the account (backend spec 017 FR-050, FR-051): refused while
/// anything is in progress or money is left; nothing is deleted.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  String? _reason;
  bool _error = false;
  bool _busy = false;
  final _note = TextEditingController();
  int _reload = 0;

  static const _reasons = [
    ChoiceOption('finished', 'I finished what I came for'),
    ChoiceOption('fees_too_high', 'Fees are too high'),
    ChoiceOption('too_slow_to_sell', 'It took too long to sell'),
    ChoiceOption('data_trust', "I don't trust it with my data"),
    ChoiceOption('something_went_wrong', 'Something went wrong', 'We would rather fix it'),
    ChoiceOption('other', 'Another reason'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_reason == null) return setState(() => _error = true);
    final ok = await ask(context, title: 'Close your account', body: 'You are signed out on every device and cannot sign in again with this number.', yes: 'Close my account');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final note = _reason == 'other' && _note.text.trim().isNotEmpty ? _note.text.trim() : null;
      await context.read<AccountRepository>().close(reason: _reason!, note: note, idempotencyKey: newIdempotencyKey());
      if (!mounted) return;
      await context.read<AuthController>().endLocally();
      if (!mounted) return;
      showToast(context, 'Your account is closed.');
      context.enterApp(R.splash);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'account_has_open_items') {
        setState(() => _reload++);
      }
      showToast(context, accountErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.delete,
      child: AsyncView<List<CloseBlocker>>(
        key: ValueKey(_reload),
        load: context.read<AccountRepository>().closeCheck,
        builder: (context, blockers) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (blockers.isNotEmpty) ...[
              DCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: DIcon('alert-triangle', size: 18, color: DColors.bad),
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: T(
                            'You have things in progress',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DColors.bad),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    for (final b in blockers) DCheckLine(b.label, icon: 'alert-triangle', iconColor: DColors.bad, bottom: 4),
                    const Gap(6),
                    const T(
                      'Finish or cancel these, and withdraw your balance, before you can close the account.',
                      style: TextStyle(fontSize: 11, color: DColors.ink3, height: 1.7),
                    ),
                    const Gap(12),
                    DButton.ghost(
                      "See what's open",
                      small: true,
                      onTap: () => context.nav(
                        blockers.any((b) => b.code == 'wallet_balance' || b.code == 'pending_withdrawal' || b.code == 'pending_topup') && blockers.length == 1
                            ? R.wallet
                            : R.orders,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
            ],
            const DLabel('Why are you leaving?'),
            DChoiceList<String>(
              value: _reason,
              onChanged: (v) => setState(() {
                _reason = v;
                _error = false;
              }),
              options: _reasons,
            ),
            if (_reason == 'other') ...[const Gap(14), DInput(controller: _note, maxLines: 3, hint: 'Anything you want to add? It helps.')],
            const Gap(16),
            const DCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DLabel('What happens to your data'),
                  T('Full detail is in the privacy policy.', style: TextStyle(fontSize: 11, color: DColors.ink3, height: 1.65)),
                  Gap(10),
                  DCheckLine('You are signed out everywhere and your pieces leave the market straight away.'),
                  DCheckLine(
                    'Records tied to your account, your ID check and the sales you made, including tax invoices, are kept for the period the law requires.',
                    icon: 'file-check',
                    iconColor: DColors.ink3,
                    bottom: 0,
                  ),
                ],
              ),
            ),
            const Gap(16),
            const DNote(icon: 'info-circle', text: 'Changed your mind about the app but not your account? You can just sign out, and come back any time.'),
            const Gap(16),
            DError('Choose a reason before closing your account.', visible: _error, top: 0),
            if (_error) const Gap(7),
            DButton('Close my account', kind: DButtonKind.danger, loading: _busy, onTap: blockers.isEmpty ? _close : null),
            const Gap(9),
            DButton.ghost('Keep my account', onTap: () => context.nav(R.account)),
          ],
        ),
      ),
    );
  }
}

/// `#s-invite`
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.invite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const DIcon('users', size: 30, color: DColors.gold),
                const Gap(10),
                const T('Invite a friend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const Gap(6),
                const T(
                  'She pays a lower commission on her first sale. You pay a lower one on your next.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: DColors.ink2, height: 1.65),
                ),
                const Gap(14),
                const DSoft.paper(
                  child: Column(
                    children: [
                      T('Your code', style: DText.tiny),
                      Gap(3),
                      Text('MONA4417', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 2)),
                    ],
                  ),
                ),
                const Gap(12),
                DActsRow(
                  children: [
                    DButton('Share', small: true, onTap: () => showToast(context, 'Ready to share.')),
                    DButton.ghost('Copy', small: true, onTap: () => showToast(context, 'Copied.')),
                  ],
                ),
              ],
            ),
          ),
          const Gap(16),
          const DLabel('Where it stands'),
          const DSoft.bordered(
            child: Column(
              children: [
                DRow('Invites sent', '3'),
                DRow('Joined', '1'),
                DRow('Sold something', '1'),
                DRow(
                  'Earned so far',
                  '200 EGP',
                  rule: true,
                  valueColor: DColors.ok,
                  valueStyle: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Gap(14),
          const T('The reward lands as commission credit after your friend completes her first sale, not when she signs up.', style: DText.tiny),
        ],
      ),
    );
  }
}

/// `#s-prices` — where prices come from.
class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget source(String icon, String title, String sub, String body) => DCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: DIcon(icon, size: 19, color: DColors.gold),
              ),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(title, style: DText.title),
                  T(sub, style: DText.tiny),
                ],
              ),
            ],
          ),
          const Gap(9),
          T(body, style: const TextStyle(fontSize: 12, color: DColors.ink2, height: 1.7)),
        ],
      ),
    );
    const partners = [('Evolve', 'Gold pricing'), ('IGI', 'Authentication'), ('Legal Clinic', 'Legal partner')];
    return AppPage(
      id: R.prices,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Two independent references decide what your jewellery is worth, not us. Evolve prices the gold and Rapaport guides the diamonds.', style: DText.muted),
          const Gap(18),
          source(
            'chart-line',
            'Evolve',
            'The gold rate',
            'We take the gold rate from Evolve and apply it to the weight and karat of your piece. We do not adjust it by hand, and it updates through the day.',
          ),
          source(
            'diamond',
            'Rapaport',
            'The diamond guide',
            'Diamond suggestions come from the Rapaport price list, the reference the trade uses worldwide, converted to Egyptian pounds. It is a guide, not a valuation. IGI decides the real grade.',
          ),
          const DSoft.bordered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DLabel('Dahab commission'),
                DRow('On gold', '20% of the making charge'),
                DRow('On stones', '5% of the value you add'),
                DRow('Minimum', '200 EGP'),
                Gap(8),
                T('Taken from the making charge or the value you add, never from the value of your gold.', style: DText.tiny),
              ],
            ),
          ),
          const Gap(14),
          const DNote(
            icon: 'shield-check',
            kind: NoteKind.ok,
            text: 'Every number in this app comes from these references or from the commission above. Nothing is hidden in between.',
          ),
          const Gap(16),
          const DLabel('Who we work with'),
          const Gap(1),
          Row(
            children: [
              for (var i = 0; i < partners.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DColors.white,
                          border: Border.all(color: DColors.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          partners[i].$1,
                          style: const TextStyle(fontFamily: DFonts.serif, fontSize: 11, color: DColors.ink3),
                        ),
                      ),
                      const Gap(5),
                      T(partners[i].$2, style: DText.tiny, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const Gap(9),
          const Center(
            child: T('Logos go here once each partner approves the artwork.', style: DText.tiny, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
