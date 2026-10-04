import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../services/account_controller.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';

/// `#s-security`
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;

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

  void _change() {
    if (_current.text.isEmpty) return setState(() => _error = 'Enter your password.');
    if (_next.text.length < 8) return setState(() => _error = 'Your password needs at least 8 characters.');
    setState(() => _error = null);
    _current.clear();
    _next.clear();
    showToast(context, 'Password changed.');
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.security,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Changing the password and the device list are still mock (no backend yet).
          MockMark(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          DButton.ghost('Change password', onTap: _change),
            ]),
          ),
          const Gap(20),
          const DLabel('Devices signed in'),
          MockMark(
            child: AsyncView<List<DeviceSession>>(
            load: context.read<AccountRepository>().devices,
            loadingHeight: 100,
            builder: (context, devices) => DMenuCard(
              children: [
                for (final d in devices)
                  DMenu(
                    icon: 'device-mobile',
                    title: d.name,
                    sub: d.sub,
                    trailing: d.current
                        ? const DPill('Current')
                        : DLink(
                            'Sign out',
                            style: const TextStyle(fontSize: 12, color: DColors.bad),
                            onTap: () => showToast(context, 'Signed out of that device.'),
                          ),
                  ),
              ],
            ),
          )),
          if (context.watch<AuthController>().isSignedIn) ...[
            const Gap(12),
            DButton.ghost('Sign out of every device', loading: _signingOut, foreground: DColors.bad, onTap: _signOutEverywhere),
          ],
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

/// `#s-notif` — notification preferences.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AccountController>().load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AccountController>();
    return AppPage(
      id: R.notif,
      child: !c.loaded
          ? const DLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DMenuCard(
                  children: [
                    for (final p in c.prefs)
                      DMenu(
                        title: p.title,
                        sub: p.sub,
                        onTap: p.locked ? null : () => c.togglePref(p),
                        trailing: p.on ? const DPill('On') : const DPill('Off', kind: PillKind.bad),
                      ),
                  ],
                ),
                const Gap(14),
                const T('Tap a row to switch it. Deadline and request alerts stay on because money depends on them.', style: DText.tiny),
              ],
            ),
    );
  }
}

/// `#s-inbox` — notifications feed.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  static Color? _tone(String t) => switch (t) {
    'ok' => DColors.ok,
    'bad' => DColors.bad,
    'wait' => DColors.wait,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.inbox,
      child: Column(
        children: [
          AsyncView<List<AppNotification>>(
            load: context.read<AccountRepository>().notifications,
            loadingHeight: 300,
            builder: (context, items) => items.isEmpty
                ? const DEmpty(icon: 'bell', title: 'No notifications yet', body: 'Nothing here yet')
                : DMenuCard(
                    children: [for (final n in items) DMenu(icon: n.icon, iconColor: _tone(n.tone), title: n.title, sub: n.sub, onTap: () => context.nav(n.target))],
                  ),
          ),
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

/// `#s-legal`
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.legal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DMenuCard(
            children: [
              for (final (title, toast) in const [
                ('Terms of use', 'Opening the terms.'),
                ('Privacy policy', 'Opening the policy.'),
                ('Selling rules and deadlines', 'Opening the rules.'),
                ('How we handle your ID and documents', 'Opening the notice.'),
              ])
                DMenu(title: title, onTap: () => showToast(context, toast)),
            ],
          ),
          const Gap(14),
          const T('Dahab acts as an intermediary between buyer and seller. The full terms explain what that means for each side.', style: DText.tiny),
        ],
      ),
    );
  }
}

/// `#s-support` — contact channels.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void toast(String m) => showToast(context, m);
    return AppPage(
      id: R.support,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DLabel('Talk to us', bottom: 10),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: DIcon('device-mobile', size: 19, color: DColors.gold),
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          T('16000', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          T('Sunday to Thursday, 10:00 to 18:00', style: DText.tiny),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(14),
                DButton('Call now', small: true, onTap: () => toast('Calling 16000.')),
              ],
            ),
          ),
          const Gap(14),
          DMenuCard(
            children: [
              DMenu(icon: 'help', title: 'Chat with us', sub: 'Usually answered within 10 minutes', onTap: () => toast('Chat opening.')),
              DMenu(icon: 'device-mobile', title: 'WhatsApp', sub: '010 4417 2026', onTap: () => toast('WhatsApp opening.')),
              DMenu(icon: 'mail', title: 'Email us', sub: 'help@dahabapp.com', onTap: () => toast('Mail opening.')),
            ],
          ),
          const Gap(14),
          const DLabel('Follow Dahab'),
          DMenuCard(
            children: [
              DMenu(icon: 'users', title: 'Facebook', sub: '@dahabapp', onTap: () => toast('Opening Facebook.')),
              DMenu(icon: 'camera', title: 'Instagram', sub: '@dahabapp', onTap: () => toast('Opening Instagram.')),
              DMenu(icon: 'video', title: 'TikTok', sub: '@dahabapp', onTap: () => toast('Opening TikTok.')),
            ],
          ),
          const Gap(16),
          const DNote(icon: 'shield-lock', text: 'Dahab will never ask for your password or your code, on any channel. If someone does, it is not us.'),
        ],
      ),
    );
  }
}

/// `#s-delete` — close account (blocked while things are in progress).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  int? _reason;
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.delete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          T(
                            'You have things in progress',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DColors.bad),
                          ),
                          Gap(4),
                          T(
                            'A gold ring is at IGI, and a balance of 62,720 EGP is due on a piece you are buying. Your wallet holds 56,760 EGP.',
                            style: TextStyle(fontSize: 11, color: DColors.ink3, height: 1.7),
                          ),
                          Gap(8),
                          T(
                            'Finish or cancel these, and withdraw your balance, before you can close the account.',
                            style: TextStyle(fontSize: 11, color: DColors.ink3, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                DButton.ghost("See what's open", small: true, onTap: () => context.nav(R.orders)),
              ],
            ),
          ),
          const Gap(16),
          const DLabel('Why are you leaving?'),
          DChoiceList<int>(
            value: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              _error = false;
            }),
            options: const [
              ChoiceOption(1, 'I finished what I came for'),
              ChoiceOption(2, 'Fees are too high'),
              ChoiceOption(3, 'It took too long to sell'),
              ChoiceOption(4, "I don't trust it with my data"),
              ChoiceOption(5, 'Something went wrong', 'We would rather fix it'),
              ChoiceOption(6, 'Another reason'),
            ],
          ),
          const Gap(14),
          const DInput(maxLines: 3, hint: 'Anything you want to add? It helps.'),
          const Gap(16),
          const DCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DLabel('What happens to your data'),
                T('Full detail is in the privacy policy.', style: TextStyle(fontSize: 11, color: DColors.ink3, height: 1.65)),
                Gap(10),
                DCheckLine('Your profile, photos and listings are removed straight away.'),
                DCheckLine('The photos of your ID are deleted. We keep only a short record that we checked it, and when.'),
                DCheckLine(
                  'Records tied to sales you already made, including tax invoices, are kept for the period the law requires, then deleted. We cannot remove those earlier.',
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
          DButton(
            'Close my account',
            kind: DButtonKind.danger,
            onTap: () {
              if (_reason == null) return setState(() => _error = true);
              tell(
                context,
                title: 'Not yet',
                body: 'You still have a piece at IGI and a balance to pay. Finish or cancel those, and withdraw your wallet, then you can close the account.',
              );
            },
          ),
          const Gap(9),
          DButton.ghost('Keep my account', onTap: () => context.nav(R.account)),
        ],
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
