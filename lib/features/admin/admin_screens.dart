import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

/// Header block of a promo code card.
class _CodeHead extends StatelessWidget {
  const _CodeHead(this.code, this.sub, {this.on = true});

  final String code;
  final String sub;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1)),
              const Gap(3),
              T(sub, style: DText.tiny),
            ],
          ),
        ),
        on ? const DPill('On') : const DPill('Off', kind: PillKind.bad),
      ],
    );
  }
}

/// `#s-codes` — admin: promo codes.
class PromoCodesScreen extends StatelessWidget {
  const PromoCodesScreen({super.key});

  Future<void> _kill(BuildContext context, String code) async {
    final ok = await ask(
      context,
      title: '${context.tr('Turn off')} $code',
      body: 'Nothing can be used with this code until you turn it back on. Anything already in progress carries on as normal.',
      yes: 'Turn it off',
    );
    if (ok && context.mounted) showToast(context, 'Code turned off and logged against your name.');
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.codes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(icon: 'lock', text: 'Admin only. Codes are checked on the server, never in the app, and every use is logged.'),
          const Gap(16),
          const DLabel('Active codes'),
          DCard(
            child: Column(
              children: [
                const _CodeHead('MM-KARIM', 'Market maker, tied to one account'),
                const Gap(10),
                const DSoft.paper(
                  child: Column(
                    children: [
                      DRow('Tied to', 'Karim S. · +20 10 •••• 8842'),
                      DRow('Commission', 'Waived'),
                      DRow('Buy and sell difference', 'Goes to them'),
                      DRow('Listing must be older than', '7 days', rule: true),
                      DRow('Admin approval on the piece', 'Required'),
                      DRow('Monthly cap', '500,000 EGP', rule: true),
                      DRow('Used this month', '312,400 EGP', valueColor: DColors.wait),
                    ],
                  ),
                ),
                const Gap(10),
                DActsRow(
                  children: [
                    DButton.ghost('See every use', small: true, onTap: () => context.nav(R.codeuses)),
                    DButton.ghost('Turn off', small: true, onTap: () => _kill(context, 'MM-KARIM')),
                  ],
                ),
              ],
            ),
          ),
          const Gap(10),
          const DCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CodeHead('MM-HODA', 'Market maker, tied to one account', on: false),
                Gap(10),
                T('Turned off 26 Aug by A. Mostafa. Nothing can be used with it until it is turned back on.', style: DText.tiny),
              ],
            ),
          ),
          const Gap(10),
          const DCard(
            child: Column(
              children: [
                _CodeHead('WELCOME', 'Open to everyone, first sale only'),
                Gap(10),
                DSoft.paper(child: Column(children: [DRow('Commission', '50% off'), DRow('Once per', 'ID card')])),
              ],
            ),
          ),
          const Gap(14),
          DButton.ghost('Add a code', onTap: () => showToast(context, 'Opening the new code form.')),
        ],
      ),
    );
  }
}

/// `#s-codeuses` — admin: every use of one code.
class CodeUsesScreen extends StatelessWidget {
  const CodeUsesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.codeuses,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DCard(
            padding: const EdgeInsets.all(13),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MM-KARIM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const Gap(3),
                  T('18 uses this month · 312,400 EGP of 500,000', style: DText.tiny),
                ],
              ),
            ),
          ),
          const Gap(14),
          const DLabel('Every use'),
          const DMenuCard(
            children: [
              DMenu(title: 'Gold bangle, 21K · 30.00 g', sub: '28 Aug, 14:20 · iPhone, Cairo · 253,050 EGP', trailing: DPill('Allowed')),
              DMenu(title: 'Gold ring, 21K · 8.00 g', sub: '27 Aug, 11:05 · iPhone, Cairo · 58,200 EGP', trailing: DPill('Allowed')),
              DMenu(
                title: 'Diamond ring, 0.8 ct',
                sub: '26 Aug, 19:40 · iPhone, Cairo',
                trailing: DPill('Blocked', kind: PillKind.bad),
              ),
              DMenu(
                title: 'Gold chain, 21K · 12.40 g',
                sub: '25 Aug, 09:12 · iPhone, Cairo',
                trailing: DPill('Blocked', kind: PillKind.bad),
              ),
            ],
          ),
          const Gap(14),
          const DLabel('Why the blocks happened'),
          const DSoft.bordered(child: Column(children: [DRow('26 Aug', 'Listed 2 days ago, needs 7'), DRow('25 Aug', 'Piece not approved by admin')])),
          const Gap(14),
          const DNote(icon: 'info-circle', text: 'A different device or a different account is refused before anything is priced. You are notified either way.'),
        ],
      ),
    );
  }
}

/// `#s-mmapprove` — admin: approve old listings for market makers.
class MarketMakerApproveScreen extends StatelessWidget {
  const MarketMakerApproveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<Widget> actions() => [
      const Gap(10),
      DActsRow(
        children: [
          DButton('Price is sound', small: true, onTap: () => showToast(context, 'Approved and logged against your name.')),
          DButton.ghost('Leave it', small: true, onTap: () => showToast(context, 'Left as it is.')),
        ],
      ),
    ];
    return AppPage(
      id: R.mmapprove,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(icon: 'info-circle', text: 'Only pieces older than 7 days appear here, so a market maker never gets ahead of an ordinary buyer.'),
          const Gap(16),
          const DLabel('Waiting on you'),
          DCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('Gold bangle, 21K', style: DText.title),
                const Gap(3),
                const T('Listed 9 days ago · 30.00 g · making charge 400 per gram', style: DText.tiny),
                const Gap(10),
                const DSoft.paper(
                  child: Column(
                    children: [
                      DRow('Asking price', '253,050 EGP'),
                      DRow('Gold value today', '208,530 EGP'),
                      DRow('Making charge as % of gold', '21%', valueColor: DColors.ok),
                      DRow('Views, no requests', '127', rule: true),
                    ],
                  ),
                ),
                ...actions(),
              ],
            ),
          ),
          const Gap(10),
          DCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('Diamond ring, 0.8 ct', style: DText.title),
                const Gap(3),
                const T('Listed 11 days ago · VS1, G colour', style: DText.tiny),
                const Gap(10),
                const DSoft.paper(
                  child: Column(
                    children: [
                      DRow('Asking price', '120,000 EGP'),
                      DRow('Rapaport guide', '92,000 EGP'),
                      DRow('Above the guide by', '30%', valueColor: DColors.bad),
                    ],
                  ),
                ),
                const Gap(10),
                const DNote(icon: 'alert-triangle', kind: NoteKind.wait, text: 'Priced well above the guide. Approving this puts the risk on the buyer.'),
                ...actions(),
              ],
            ),
          ),
          const Gap(14),
          const T('Every approval is logged with your name and the numbers you saw when you made it.', style: DText.tiny),
        ],
      ),
    );
  }
}

/// `#s-compensate` — admin: pay compensation to a seller.
class CompensateScreen extends StatefulWidget {
  const CompensateScreen({super.key});

  @override
  State<CompensateScreen> createState() => _CompensateScreenState();
}

class _CompensateScreenState extends State<CompensateScreen> {
  int? _reason;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_reason == null || _amount.text.trim().isEmpty || _note.text.trim().isEmpty) return setState(() => _error = true);
    await tell(context, title: 'Paid', body: 'It is in the seller wallet and logged against your name.');
    if (mounted) context.nav(R.account);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.compensate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(icon: 'lock', text: "Admin only. Every payment here is logged with your name and appears on the seller's statement."),
          const Gap(16),
          const DCard(
            padding: EdgeInsets.all(13),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T('Seller 4417', style: DText.title),
                  Gap(3),
                  T('Order DH-2026-004417', style: DText.tiny),
                ],
              ),
            ),
          ),
          const Gap(14),
          const DLabel('Why'),
          DChoiceList<int>(
            value: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              _error = false;
            }),
            options: const [
              ChoiceOption(1, 'A delay caused by IGI'),
              ChoiceOption(2, "A mistake on Dahab's side"),
              ChoiceOption(3, 'A wasted trip to IGI'),
              ChoiceOption(4, 'Settlement of a dispute'),
              ChoiceOption(5, 'Goodwill'),
            ],
          ),
          const Gap(14),
          DField(
            label: 'Amount',
            bottom: 5,
            child: DInput(controller: _amount, hint: '0 EGP', keyboardType: TextInputType.number),
          ),
          const T('Daily limit for your account: 5,000 EGP', style: DText.tiny),
          const Gap(14),
          const DLabel('Note for the record'),
          DInput(controller: _note, maxLines: 3, hint: 'What happened, in one or two lines.'),
          const Gap(14),
          const DSoft.bordered(child: Column(children: [DRow('Approved by', 'A. Mostafa'), DRow('Shows on the statement as', 'Compensation from Dahab')])),
          const Gap(14),
          DError('Choose a reason, an amount, and write a note.', visible: _error, top: 0),
          if (_error) const Gap(7),
          DButton("Pay to the seller's wallet", onTap: _pay),
        ],
      ),
    );
  }
}
