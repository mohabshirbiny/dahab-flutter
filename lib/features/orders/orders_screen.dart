import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/listing.dart';
import '../../models/order.dart';
import '../../models/piece.dart';
import '../../services/api/api_client.dart';
import '../../services/repositories.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';
import '../shared/order_card.dart';

/// `#s-orders` — state and role filters over a swipeable card carousel.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _stage = 'all';
  String _role = 'all';
  late final Future<List<OrderCardData>> _future = context.read<OrdersRepository>().orders();

  List<OrderCardData> _filter(List<OrderCardData> all) => all.where((o) {
    final okStage = _stage == 'all' || o.stage.name == _stage;
    final okRole = _role == 'all' || o.role.name == _role;
    return okStage && okRole;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.orders,
      padded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DChips(
              children: [
                for (final (id, label) in const [('all', 'All'), ('action', 'Needs you'), ('waiting', 'Waiting'), ('done', 'Finished')])
                  DChip(label, on: _stage == id, onTap: () => setState(() => _stage = id)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: DChips(
              children: [
                for (final (id, label) in const [('all', 'Everything'), ('sell', 'Selling'), ('buy', 'Buying')])
                  DChip(label, on: _role == id, onTap: () => setState(() => _role = id)),
              ],
            ),
          ),
          FutureBuilder<List<OrderCardData>>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) return const DLoading(height: 300);
              final all = snap.data!;
              if (all.isEmpty) {
                return DEmpty(
                  icon: 'clipboard-list',
                  title: 'Nothing on the go yet',
                  body: 'When you list a piece or ask to buy one, it shows up here with everything you need to do next.',
                  action: 'Sell a piece',
                  onAction: context.trySell,
                );
              }
              final list = _filter(all);
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  child: Column(
                    children: [
                      Center(child: Text('0 of 0', style: DText.tiny)),
                      Gap(20),
                      T('Nothing here', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Gap(5),
                      T('No orders match these two filters. Try widening one of them.', style: DText.tiny, textAlign: TextAlign.center),
                    ],
                  ),
                );
              }
              return OrderCarousel(key: ValueKey('$_stage-$_role'), orders: list);
            },
          ),
        ],
      ),
    );
  }
}

/// `.hscroll` of `.ord` cards: each card is 88% wide and snaps to the
/// centre, with a "1 of N" counter and dots above.
class OrderCarousel extends StatefulWidget {
  const OrderCarousel({super.key, required this.orders});

  final List<OrderCardData> orders;

  @override
  State<OrderCarousel> createState() => _OrderCarouselState();
}

class _OrderCarouselState extends State<OrderCarousel> {
  final _controller = ScrollController();
  int _index = 0;
  List<double> _offsets = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (_offsets.isEmpty) return;
    final px = _controller.offset;
    var best = 0;
    for (var i = 1; i < _offsets.length; i++) {
      if ((_offsets[i] - px).abs() < (_offsets[best] - px).abs()) best = i;
    }
    if (best != _index) setState(() => _index = best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final viewport = c.maxWidth;
        final cardW = (viewport - 32) * 0.88;
        const gap = 12.0;
        final n = widget.orders.length;
        final content = 32 + n * cardW + (n - 1) * gap;
        final maxScroll = (content - viewport).clamp(0.0, double.infinity);
        _offsets = [for (var i = 0; i < n; i++) (16 + i * (cardW + gap) - (viewport - cardW) / 2).clamp(0.0, maxScroll)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  T('${_index + 1} of $n', style: DText.tiny),
                  const Spacer(),
                  _Dots(count: n, index: _index),
                ],
              ),
            ),
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: _SnapPhysics(offsets: _offsets),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < n; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: cardW,
                      child: OrderCard(data: widget.orders[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == index ? DColors.ink : DColors.line2, borderRadius: BorderRadius.circular(3)),
          ),
        ],
      ],
    );
  }
}

/// `scroll-snap-type:x mandatory` — settle on the nearest card, or the next
/// one in the fling direction.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.offsets, super.parent});

  final List<double> offsets;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(offsets: offsets, parent: buildParent(ancestor));

  double _target(double px, double velocity) {
    if (offsets.isEmpty) return px;
    var nearest = 0;
    for (var i = 1; i < offsets.length; i++) {
      if ((offsets[i] - px).abs() < (offsets[nearest] - px).abs()) nearest = i;
    }
    if (velocity.abs() > 250) {
      if (velocity > 0 && offsets[nearest] <= px && nearest < offsets.length - 1) nearest++;
      if (velocity < 0 && offsets[nearest] >= px && nearest > 0) nearest--;
    }
    return offsets[nearest];
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) || (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _target(position.pixels, velocity).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(SpringDescription.withDampingRatio(mass: 0.5, stiffness: 120, ratio: 1), position.pixels, target, velocity, tolerance: toleranceFor(position));
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// `#s-listings` — the seller's own pieces, from the backend (spec 010).
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String _filter = 'All';
  int _reload = 0;
  bool _busy = false;

  /// The prototype's chips are decorative; here they filter by state.
  static const _groups = {
    // A reserved piece is still on the market, with buyers in line (spec 011).
    'Live': {'live', 'reserved', 'suspended_hold'},
    'In review': {'draft', 'in_review', 'changes_requested'},
    // The seller accepted a buyer: off the market, not sold yet (spec 011).
    'Accepted': {'accepted'},
    'Sold': {'sold', 'settled'},
  };

  static String _day(DateTime d) => dayMonth(d);

  OrderCardData _card(Listing l, bool arabic) {
    final (status, tone) = switch (l.state) {
      ListingState.draft => ('Draft', Tone.wait),
      ListingState.inReview => ('Waiting for approval', Tone.wait),
      ListingState.changesRequested => ('Changes needed', Tone.bad),
      ListingState.live => ('Live', Tone.ok),
      ListingState.reserved => ('Decide today', Tone.bad),
      ListingState.accepted => ('Accepted', Tone.ok),
      ListingState.rejected => ('Not accepted', Tone.bad),
      ListingState.withdrawn => ('Taken down', Tone.neutral),
      ListingState.suspendedHold => ('On hold', Tone.wait),
      ListingState.other => ('In progress', Tone.wait),
    };
    final weight = double.tryParse(l.weight ?? '');
    final lead = switch (l.state) {
      ListingState.draft => 'Started ${_day(l.createdAt)}',
      _ when l.listedAt != null => 'Listed ${_day(l.listedAt!)}',
      _ => 'Sent ${_day(l.createdAt)}',
    };
    final making = double.tryParse(l.makingPerGram ?? '');
    final asking = double.tryParse(l.askingPrice ?? '');
    final receive = double.tryParse(l.youWouldReceive ?? '');
    final message = l.staffMessage;

    return OrderCardData(
      id: l.id,
      pieceId: l.id,
      title: arabic && l.typeNameAr.isNotEmpty ? pieceTitleAr(l.category, l.typeNameAr, l.karat) : pieceTitle(l.category, l.typeNameEn, l.karat),
      status: status,
      statusTone: tone,
      subtitle: weight == null ? lead : '$lead, ${weight.toStringAsFixed(2)} g',
      stage: l.canEdit || l.canWithdraw || l.state == ListingState.reserved ? OrderStage.action : OrderStage.waiting,
      blocks: [
        if (l.state == ListingState.live || l.state == ListingState.reserved || l.state == ListingState.suspendedHold)
          RowsBlock([
            if (making != null) KV('Your making charge', '${making.round()} per gram'),
            if (asking != null) KV('Your asking price', money(asking)),
            KV('You would receive', receive == null ? 'Not available right now' : money(receive)),
          ]),
        if (message != null && message.isNotEmpty) TextBlock(message, inset: true),
        TextBlock(switch (l.state) {
          ListingState.draft => 'This listing was not sent yet. Finish it and send it for approval.',
          ListingState.inReview => 'We are checking your photos and description. You will hear back within a few hours.',
          ListingState.changesRequested => 'Fix what we asked for and send it again.',
          ListingState.live => 'Buyers can see this piece.',
          ListingState.reserved =>
            l.queueCount == 1 ? 'A buyer sent a request. Open the piece to accept or decline it.' : '${l.queueCount} buyers are in line. Open the piece to answer the first.',
          ListingState.accepted =>
            l.order == null
                ? 'You accepted a buyer.'
                : 'You accepted a buyer (order ${l.order!.orderRef}). Bring the piece to ${l.order!.branchNameEn} by ${whenOf(l.order!.reachBranchDeadline)}.',
          ListingState.rejected => 'This listing was not accepted and is closed.',
          ListingState.withdrawn => 'This listing is off the market and closed. To sell the piece, list it again.',
          ListingState.suspendedHold => 'Your account is suspended, so this piece is hidden from buyers. It returns when the account is reinstated.',
          ListingState.other => 'This listing is in progress.',
        }),
        if (l.canEdit) ActionsBlock([OrderAction(l.state == ListingState.draft ? 'Finish and send' : 'Fix and resend', 'fix')]),
        if (l.canWithdraw) const ActionsBlock([OrderAction('Take it down', 'withdraw')]),
      ],
    );
  }

  Future<void> _act(Listing l, String action) async {
    if (_busy) return;
    if (action == 'fix') {
      context.read<SellDraft>().loadFrom(l);
      return context.nav(R.sell1);
    }
    if (action != 'withdraw') return runOrderAction(context, action);

    final ok = await ask(
      context,
      title: 'Take this listing down',
      body: 'It stops showing to buyers and the listing is closed. This cannot be undone: to sell the piece later, list it again.',
      yes: 'Take it down',
    );
    if (!ok || !mounted) return;
    _busy = true;
    try {
      await context.read<ListingsRepository>().withdraw(l.id, idempotencyKey: newIdempotencyKey());
      if (mounted) showToast(context, 'Taken down.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, listingErrorMessage(e));
    } finally {
      _busy = false;
      if (mounted) setState(() => _reload++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    return AppPage(
      id: R.listings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DNote(icon: 'chart-line', kind: NoteKind.ok, text: 'The price of a live gold piece follows the gold rate on its own. There is nothing to do.'),
          const Gap(14),
          DChips(
            children: [
              for (final c in const ['All', 'Live', 'In review', 'Accepted', 'Sold']) DChip(c, on: _filter == c, onTap: () => setState(() => _filter = c)),
            ],
          ),
          const Gap(14),
          AsyncView<List<Listing>>(
            key: ValueKey(_reload),
            load: context.read<ListingsRepository>().mine,
            builder: (context, all) {
              final list = _filter == 'All' ? all : all.where((l) => _groups[_filter]!.contains(l.rawState)).toList();
              if (list.isEmpty) {
                return DEmpty(
                  icon: 'tag',
                  title: 'Nothing here',
                  body: 'When you list a piece or ask to buy one, it shows up here with everything you need to do next.',
                  action: 'Sell a piece',
                  onAction: () {
                    context.read<SellDraft>().reset();
                    context.trySell();
                  },
                );
              }
              return Column(
                children: [
                  for (final l in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrderCard(data: _card(l, arabic), onAction: (a) => _act(l, a)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
