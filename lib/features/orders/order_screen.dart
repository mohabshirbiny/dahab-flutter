import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/dispute.dart';
import '../../models/order.dart';
import '../../models/piece.dart';
import '../../services/api/api_client.dart';
import '../../services/api/orders_api.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import 'order_flows.dart' show OrderContextCard;

/// One order from the backend (spec 012), for its buyer or its seller: where it is,
/// what to do now (bring the piece, decide on a new price, pay the balance, show the
/// code), the inspection result and the story so far. The backend says which
/// actions apply (`actions`); this screen never decides that itself.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.id});

  final String id;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  CustomerOrder? _order;
  Object? _loadError;
  bool _busy = false;

  /// The wallet was short when paying: what it needs.
  BalanceShortfall? _shortfall;

  /// One key per action on this order, so a retried tap is replayed, not repeated.
  final Map<String, String> _keys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final o = await context.read<OrdersRepository>().show(widget.id);
      if (mounted) setState(() => _order = o);
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  String _key(String action) => _keys.putIfAbsent(action, newIdempotencyKey);

  Future<void> _run(String action, Future<CustomerOrder> Function(String key) call, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final o = await call(_key(action));
      _keys.remove(action);
      if (!mounted) return;
      setState(() {
        _order = o;
        _shortfall = null;
      });
      if (done != null) showToast(context, done);
    } on ApiException catch (e) {
      if (!mounted) return;
      final short = balanceShortfallOf(e);
      if (short != null) {
        _keys.remove(action);
        setState(() => _shortfall = short);
        return;
      }
      if (!e.isNetwork) _keys.remove(action);
      showToast(context, orderErrorMessage(e));
      if (e.code == 'illegal_order_transition' || e.code == 'inspection_correction_not_allowed') unawaited(_load());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(CustomerOrder o) async {
    final ok = await ask(
      context,
      title: 'Cancel the sale',
      body:
          'This cancels the sale, it does not extend it. The buyer gets their deposit back in full, you keep the piece, and the cancellation is counted on your account. If you only need more time, ask us instead.',
      yes: 'Cancel the sale',
    );
    if (!ok || !mounted) return;
    await _run('cancel', (k) => context.read<OrdersRepository>().cancel(o.id, idempotencyKey: k), done: 'The sale is cancelled.');
  }

  Future<void> _decide(CustomerOrder o, bool accept) async {
    final inspection = o.inspection;
    if (inspection == null) return;
    if (!accept) {
      final ok = await ask(context, title: 'Decline the new price', body: 'The sale is cancelled and your deposit comes back to your wallet in full at once.', yes: 'Decline');
      if (!ok || !mounted) return;
    }
    await _run(
      accept ? 'accept' : 'decline',
      (k) => context.read<OrdersRepository>().decide(o.id, accept: accept, inspectionId: inspection.id, idempotencyKey: k),
      done: accept ? 'Accepted. Pay the balance to collect your piece.' : 'Declined. Your deposit is back in your wallet.',
    );
  }

  Future<void> _pay(CustomerOrder o) => _run('pay', (k) => context.read<OrdersRepository>().payBalance(o.id, idempotencyKey: k), done: 'Paid in full. Your code is ready.');

  Future<void> _relist(CustomerOrder o) async {
    final ok = await ask(
      context,
      title: 'Put it back on the market',
      body: 'The piece stays at the branch and goes live again with an empty line. You do not need to collect it.',
      yes: 'Put it back',
    );
    if (!ok || !mounted) return;
    await _run('relist', (k) => context.read<OrdersRepository>().relist(o.id, idempotencyKey: k), done: 'Back on the market.');
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    Widget body;
    if (o != null) {
      body = _OrderBody(
        order: o,
        busy: _busy,
        shortfall: _shortfall,
        onCancel: () => _cancel(o),
        onDecide: (accept) => _decide(o, accept),
        onPay: () => _pay(o),
        onRelist: () => _relist(o),
      );
    } else if (_loadError != null) {
      body = DErrorState(onRetry: _load);
    } else {
      body = const DLoading(height: 300);
    }
    return AppPage(id: R.order, child: body);
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order, required this.busy, required this.shortfall, required this.onCancel, required this.onDecide, required this.onPay, required this.onRelist});

  final CustomerOrder order;
  final bool busy;
  final BalanceShortfall? shortfall;
  final VoidCallback onCancel;
  final void Function(bool accept) onDecide;
  final VoidCallback onPay;
  final VoidCallback onRelist;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final (status, tone, _) = ApiOrdersRepository.statusOf(o);
    final title = context.isArabic && o.typeNameAr.isNotEmpty ? pieceTitleAr(o.category, o.typeNameAr, o.karat) : pieceTitle(o.category, o.typeNameEn, o.karat);
    final weight = double.tryParse(o.weight ?? '');
    final side = o.isSeller ? 'You are selling' : 'You are buying';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderContextCard(title, weight == null ? '${o.orderRef} · $side' : '${o.orderRef} · $side, ${weight.toStringAsFixed(2)} g'),
        const Gap(12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DPill(status, kind: _pill(tone)),
        ),
        const Gap(14),
        ..._problem(context),
        ..._stage(context),
        if (o.inspection != null) ...[const Gap(16), _InspectionPanel(order: o)],
        if (o.invoiceId != null) ...[
          const Gap(16),
          DButton.ghost('View invoice', onTap: () => context.nav(R.invoice, query: {'id': o.invoiceId!})),
        ],
        if (o.can('report_problem')) ...[
          const Gap(16),
          DButton.ghost('Report a problem', onTap: () => context.nav(R.dispute, query: {'id': o.id})),
        ],
        const Gap(16),
        const DLabel('What happened so far'),
        _Timeline(order: o),
      ],
    );
  }

  static PillKind _pill(Tone t) => switch (t) {
    Tone.ok => PillKind.ok,
    Tone.bad => PillKind.bad,
    Tone.warn => PillKind.warn,
    _ => PillKind.wait,
  };

  /// Spec 014: the order on hold, your own report with Dahab's answer, or how it ended.
  List<Widget> _problem(BuildContext context) {
    final o = order;
    final d = o.dispute;
    return [
      if (o.frozen) ...[
        const DNote(icon: 'lock', kind: NoteKind.wait, text: 'This order is on hold while Dahab looks into a problem. No money moves and no deadline runs against you.'),
        const Gap(12),
      ],
      if (d != null) ...[
        const DLabel('The problem you reported'),
        DSoft.bordered(
          child: Column(
            children: [
              DRow('Reference', d.ref),
              DRow('What went wrong', disputeReasonLabel(d.reason)),
              DRow('Reported', whenOf(d.openedAt)),
              DRow('Where it is', switch (d.state) {
                'resolved' => 'Answered',
                'being_looked_at' => 'Being looked at',
                _ => 'Received',
              }, valueColor: d.resolved ? DColors.ok : DColors.wait),
            ],
          ),
        ),
        if (d.reply != null && d.reply!.isNotEmpty) ...[
          const Gap(12),
          const DLabel("Dahab's answer"),
          DCard(
            padding: const EdgeInsets.all(13),
            child: T(d.reply!, style: const TextStyle(fontSize: 12, color: DColors.ink2, height: 1.7)),
          ),
        ],
        const Gap(14),
      ] else if (o.disputeOutcome == 'resumed' && !o.frozen) ...[
        const DNote(icon: 'info-circle', text: 'Dahab looked into a problem on this order. It is moving again, and every deadline got back the time it was on hold.'),
        const Gap(14),
      ],
    ];
  }

  /// The seller's latest request for more time.
  List<Widget> _moreTime(BuildContext context) {
    final r = order.extensionRequest;
    if (r == null) return const [];
    return [
      const Gap(12),
      switch (r.state) {
        'waiting' => const DNote(icon: 'clock', kind: NoteKind.wait, text: 'You asked for more time. We will answer soon; the deadline below still applies until then.'),
        'accepted' => DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'More time given: ${r.hoursGranted ?? 0} working hours. The deadline below is the new one.'),
        'refused' => DNote(
          icon: 'alert-triangle',
          kind: NoteKind.wait,
          text: r.answerNote == null || r.answerNote!.isEmpty ? 'We could not give more time. The deadline below still applies.' : 'We could not give more time: ${r.answerNote}',
        ),
        _ => const SizedBox.shrink(),
      },
    ];
  }

  List<Widget> _stage(BuildContext context) {
    final o = order;
    final deadline = o.deadline;
    final branch = DCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DIcon('map-pin', size: 18, color: DColors.ink2),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(o.branchNameEn, style: DText.body14),
                if (o.branchAddressEn.isNotEmpty) ...[const Gap(2), T(o.branchAddressEn, style: DText.tiny)],
              ],
            ),
          ),
        ],
      ),
    );

    switch (o.stage) {
      case CustomerOrderStage.bringPiece when o.isSeller:
        return [
          const DLabel('Bring the piece to IGI'),
          branch,
          const Gap(12),
          if (deadline != null) _Countdown(at: deadline.at, label: 'Bring it by'),
          ..._moreTime(context),
          const Gap(12),
          const DNote(icon: 'info-circle', text: 'IGI checks the karat and weight. The buyer pays the balance only after it passes, and then you are paid.'),
          if (o.can('ask_more_time')) ...[
            const Gap(16),
            DButton.ghost('I need more time', onTap: () => context.nav(R.extend, query: {'id': o.id})),
          ],
          if (o.can('cancel')) ...[const Gap(9), DButton.ghost('Cancel the sale', loading: busy, onTap: onCancel, foreground: DColors.bad)],
        ];
      case CustomerOrderStage.bringPiece:
        return [
          DSoft.bordered(
            child: Column(
              children: [
                DRow('Your price is fixed at', moneyOf(o.lockedTotalPrice)),
                DRow('Deposit held', moneyOf(o.depositHeld ?? o.depositAmount)),
                DRow('Branch', o.branchNameEn),
                if (deadline != null) DRow('The seller delivers by', whenOf(deadline.at), valueColor: DColors.wait),
              ],
            ),
          ),
          const Gap(12),
          const DNote(icon: 'clock', text: 'The seller is bringing the piece to the branch for inspection. You pay the balance only after it passes.'),
        ];
      case CustomerOrderStage.atIgi:
        return [const DNote(icon: 'clock', kind: NoteKind.wait, text: 'The piece is at IGI. We tell you as soon as the result is in.'), const Gap(12), branch];
      case CustomerOrderStage.decide when !o.isSeller:
        final inspection = o.inspection;
        if (inspection == null || inspection.pricePending || inspection.newPrice == null) {
          return const [
            DNote(
              icon: 'clock',
              kind: NoteKind.wait,
              text: "The stone came in below what was listed. Dahab is working out the new price; you decide once it is ready. Nothing is charged until then.",
            ),
          ];
        }
        return [
          const DNote(
            icon: 'alert-triangle',
            kind: NoteKind.wait,
            text: 'IGI found a difference, so the price changed. Accept the new price, or decline and get your deposit back in full.',
          ),
          const Gap(12),
          DSoft.bordered(
            child: Column(
              children: [
                DRow('The price you agreed', moneyOf(o.lockedTotalPrice)),
                DRow('The new price', moneyOf(inspection.newPrice), rule: true, bold: true),
                if (deadline != null) DRow('Decide by', whenOf(deadline.at), valueColor: DColors.wait),
              ],
            ),
          ),
          if (o.can('decide')) ...[
            const Gap(16),
            DButton('Accept the new price', loading: busy, onTap: () => onDecide(true)),
            const Gap(9),
            DButton.ghost('Decline and get my deposit back', onTap: busy ? null : () => onDecide(false)),
          ],
        ];
      case CustomerOrderStage.decide:
        return const [DNote(icon: 'clock', kind: NoteKind.wait, text: 'The buyer is deciding on the new price. Your piece is safe at the branch.')];
      case CustomerOrderStage.pay when !o.isSeller:
        final short = shortfall;
        return [
          const DLabel("What's left to pay"),
          DSoft.bordered(
            child: Column(
              children: [
                DRow('Total price', moneyOf(o.finalTotal ?? o.lockedTotalPrice)),
                DRow('Deposit already held', moneyOf(o.depositAmount)),
                DRow('Balance now', '', rule: true, bold: true, keyIsLabel: false, valueWidget: T(moneyOf(o.amountDue), style: DText.price)),
                if (deadline != null) DRow('Pay by', whenOf(deadline.at), valueColor: DColors.wait),
              ],
            ),
          ),
          if (short != null) ...[
            const Gap(14),
            DCard(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const T('You need a little more', style: DText.title),
                  const Gap(6),
                  DRow('Available in your wallet', moneyOf(short.available)),
                  DRow('Still needed', moneyOf(short.shortfall), valueColor: DColors.bad),
                  const Gap(10),
                  DButton.ghost('Add funds', small: true, onTap: () => context.nav(R.addfunds)),
                ],
              ),
            ),
          ],
          const Gap(14),
          const DNote(icon: 'shield-check', text: 'Once you pay, the seller is paid straight away and a collection code appears here. Show it at the branch to take your piece.'),
          if (o.can('pay')) ...[const Gap(16), DButton('Pay ${moneyOf(o.amountDue)}', loading: busy, onTap: onPay)],
        ];
      case CustomerOrderStage.pay:
        return const [DNote(icon: 'clock', kind: NoteKind.wait, text: 'The piece passed inspection. The buyer is paying the balance.')];
      case CustomerOrderStage.collect || CustomerOrderStage.done when o.isSeller:
        return [
          AmountBlockView(caption: 'Paid to your wallet', amount: '+ ${moneyOf(o.sellerProceeds)}'),
          const Gap(12),
          const DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'The sale is complete on your side. The buyer collects the piece from the branch.'),
        ];
      case CustomerOrderStage.collect:
        final c = o.collection;
        return [
          if (c?.windowPassed == true)
            const DNote(
              icon: 'alert-triangle',
              kind: NoteKind.wait,
              text: 'The collection window has passed, but the piece is still yours. Contact us and collect it with your code.',
            )
          else
            const DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'Paid in full. Your piece is waiting at the branch.'),
          const Gap(14),
          if (o.collectionCode != null) _CodeCard(code: o.collectionCode!, until: c?.collectDeadline),
          if (o.proxy != null) ...[
            const Gap(14),
            const DLabel('Someone else collects'),
            DSoft.bordered(child: Column(children: [DRow('Name', o.proxy!.name), DRow('Their phone', o.proxy!.phoneMasked)])),
            const Gap(8),
            const T('They got the code by SMS. The branch checks their ID against the name above.', style: DText.tiny),
          ],
          const Gap(14),
          branch,
          if (o.can('name_proxy')) ...[
            const Gap(14),
            DButton.ghost(o.proxy == null ? 'Someone else will collect it' : 'Change who collects', onTap: () => context.nav(R.proxy, query: {'id': o.id})),
          ],
        ];
      case CustomerOrderStage.done:
        return const [DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'You collected the piece. The sale is complete.')];
      case CustomerOrderStage.cancelled || CustomerOrderStage.other:
        final back = o.sellerReturn;
        return [
          DSoft.paper(
            child: T(ApiOrdersRepository.cancelReasonText(o), style: DText.tiny.copyWith(color: DColors.ink2, height: 1.65)),
          ),
          if (!o.isSeller && o.cancelReasonKind != 'no_pay') ...[
            const Gap(12),
            AmountBlockView(caption: 'Deposit returned to your wallet', amount: '+ ${moneyOf(o.depositAmount)}'),
          ],
          if (o.isSeller && back != null) ...[
            const Gap(14),
            if (back.collectedAt != null)
              const DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'You collected the piece.')
            else if (back.relistedAt != null)
              const DNote(icon: 'circle-check', kind: NoteKind.ok, text: 'The piece is back on the market.')
            else ...[
              DNote(
                icon: 'package',
                kind: NoteKind.wait,
                text: back.windowPassed
                    ? 'The time to collect has passed, but the piece is still yours. Contact us to collect it.'
                    : 'Your piece is waiting for you at the branch. Collect it with your code, or put it back on the market.',
              ),
              const Gap(14),
              if (o.returnCode != null) _CodeCard(code: o.returnCode!, until: back.returnDeadline, title: 'Your code'),
              const Gap(14),
              branch,
              if (o.can('relist')) ...[const Gap(14), DButton.ghost('Put it back on the market', loading: busy, onTap: onRelist)],
            ],
          ],
        ];
    }
  }
}

/// The green "+ 24,000 EGP" panel.
class AmountBlockView extends StatelessWidget {
  const AmountBlockView({super.key, required this.caption, required this.amount});

  final String caption;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return DSoft.paper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          T(caption, style: DText.tiny),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: T(
              amount,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: DColors.ok),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Show this code at the counter".
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, this.until, this.title = 'Show this code at the counter'});

  final String code;
  final DateTime? until;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            T(title, style: DText.tiny),
            const Gap(10),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(code.split('').join(' '), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: 4)),
            ),
            if (until != null) ...[const Gap(10), T('Collect before ${whenOf(until!)}', style: DText.tiny)],
            const Gap(6),
            const T('Bring your ID. Never share this code with anyone but the branch.', style: DText.tiny, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// What IGI found: stated against measured, the note and the certificate.
class _InspectionPanel extends StatelessWidget {
  const _InspectionPanel({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final r = order.inspection!;
    final karatOk = r.measuredKarat == null || r.measuredKarat == r.statedKarat;
    final diff = double.tryParse(r.weightDiffPct ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DLabel('What IGI found'),
        DSoft.bordered(
          child: Column(
            children: [
              if (r.statedKarat != null) DRow('Karat listed', '${r.statedKarat}K'),
              if (r.measuredKarat != null) DRow('Karat measured', '${r.measuredKarat}K', valueColor: karatOk ? DColors.ok : DColors.bad),
              if (r.statedWeight != null) DRow('Weight listed', '${(double.tryParse(r.statedWeight!) ?? 0).toStringAsFixed(2)} g', rule: true),
              if (r.measuredWeight != null)
                DRow('Weight measured', '${(double.tryParse(r.measuredWeight!) ?? 0).toStringAsFixed(2)} g', valueColor: diff == null || diff == 0 ? DColors.ok : DColors.wait),
              if (r.stoneGrade != null) DRow('Stone grade', r.stoneGrade!, rule: true),
              if (r.certificateNumber != null) DRow('Certificate', r.certificateNumber!),
              if (r.inspectedAt != null) DRow('Inspected', whenOf(r.inspectedAt!)),
            ],
          ),
        ),
        if (r.note != null && r.note!.isNotEmpty) ...[
          const Gap(12),
          const DLabel("The inspector's note"),
          DCard(
            padding: const EdgeInsets.all(13),
            child: T(r.note!, style: const TextStyle(fontSize: 12, color: DColors.ink2, height: 1.7)),
          ),
        ],
      ],
    );
  }
}

/// The order's story, oldest first, in plain words.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final CustomerOrder order;

  String _what(OrderTimelineEvent e) => switch (e.event) {
    'accepted' => order.isSeller ? 'You accepted the buyer' : 'The seller accepted your request',
    'received' => 'The piece reached the branch',
    'result' => e.detail['corrects'] != null ? 'IGI corrected the result' : 'IGI inspected the piece',
    'price_proposed' => 'Dahab set the new price',
    'decision' => e.detail['accepted'] == true ? 'The new price was accepted' : 'The new price was declined',
    'paid' => 'The balance was paid',
    'collected' => 'The buyer collected the piece',
    'forfeited' => 'The balance was not paid in time',
    'cancelled' => 'The sale was cancelled',
    'branch_changed' => 'The branch changed',
    'deadline_extended' => 'A deadline was extended',
    'returned' => 'The piece is held at the branch for the seller',
    'relisted' => 'The piece went back on the market',
    'return_collected' => 'The seller collected the piece',
    _ => 'Updated',
  };

  @override
  Widget build(BuildContext context) {
    final events = order.timeline;
    return DTrack(steps: [for (var i = 0; i < events.length; i++) DStep(_what(events[i]), whenOf(events[i].at), state: i == events.length - 1 ? TrackState.now : TrackState.done)]);
  }
}

/// A deadline that counts down every minute.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.at, required this.label});

  final DateTime at;
  final String label;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.at.difference(DateTime.now());
    final text = left.isNegative ? 'Time is up' : (left.inHours >= 1 ? '${left.inHours} h ${left.inMinutes % 60} min left' : '${left.inMinutes} min left');
    return DSoft.bordered(
      child: Column(
        children: [
          DRow(widget.label, whenOf(widget.at)),
          DRow('Time left', text, valueColor: left.isNegative || left.inHours < 3 ? DColors.bad : DColors.wait),
        ],
      ),
    );
  }
}
