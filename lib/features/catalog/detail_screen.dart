import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/buy_request.dart';
import '../../models/listing.dart';
import '../../models/piece.dart';
import '../../services/api/api_client.dart';
import '../../services/api/buy_requests_api.dart';
import '../../services/app_session.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/media_tab.dart';
import '../../services/repositories.dart';
import '../../services/sell_draft.dart';
import '../../widgets/widgets.dart';
import '../shared/listing_ui.dart';
import '../shared/piece_card.dart';

DetailView parseDetailView(String? v) => switch (v) {
  'owner' => DetailView.owner,
  'cancelled' => DetailView.cancelled,
  'requested' => DetailView.requested,
  'accepted' => DetailView.accepted,
  _ => DetailView.buyer,
};

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// `#s-detail` — one piece, in the state it was opened from.
///
/// A piece from the backend (spec 010) shows what the market returns; the
/// owner opening their own listing sees it in any state, private files
/// included. The prototype's extras with no backend yet (views, seller line,
/// deposit) only show for the mock pieces.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.view, required this.pieceId});

  final DetailView view;
  final String pieceId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<(PieceDetail, BuyRequest?)> _future = _load();

  Future<(PieceDetail, BuyRequest?)> _load() async {
    if (widget.view == DetailView.owner && _uuid.hasMatch(widget.pieceId)) {
      return (PieceDetail.fromListing(await context.read<ListingsRepository>().show(widget.pieceId)), null);
    }
    final buyRequests = context.read<BuyRequestsRepository>();
    final signedIn = context.read<AuthController>().isSignedIn;
    final detail = await context.read<CatalogRepository>().detail(widget.pieceId);
    return (detail, signedIn && _uuid.hasMatch(widget.pieceId) ? await _myRequest(buyRequests) : null);
  }

  // A block body: a setState callback must not return the Future it assigns.
  void _reload() => setState(() {
    _future = _load();
  });

  /// The buyer's own active request on this piece (backend spec 011), if any.
  Future<BuyRequest?> _myRequest(BuyRequestsRepository repo) async {
    try {
      final rows = await repo.mine(listingId: widget.pieceId);
      return rows.where((r) => r.state == BuyRequestState.queued || r.state == BuyRequestState.accepted).firstOrNull;
    } on ApiException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.isArabic;
    return FutureBuilder<(PieceDetail, BuyRequest?)>(
      future: _future,
      builder: (context, snap) {
        final piece = snap.data?.$1.piece;
        final title = piece == null ? '' : (arabic && piece.titleAr != null ? piece.titleAr! : piece.title);
        return AppPage(
          id: R.detail,
          // The prototype's title is the piece name ("Gold ring").
          title: title.split(RegExp('[,،]')).first,
          padded: false,
          child: snap.hasError
              ? _Gone(error: snap.error!, onRetry: _reload)
              : snap.hasData
              ? _DetailBody(d: snap.data!.$1, mine: snap.data!.$2, view: widget.view, onChanged: _reload)
              : const DLoading(height: 400),
        );
      },
    );
  }
}

/// The piece left the market (sold, taken down) or could not be loaded.
class _Gone extends StatelessWidget {
  const _Gone({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e is ApiException && e.status == 404) {
      return DEmpty(
        icon: 'tag',
        title: 'This piece is no longer on the market',
        body: 'It was sold or taken down. There are other pieces to look at.',
        action: 'See all',
        onAction: () => context.nav(R.browse),
      );
    }
    return DErrorState(onRetry: onRetry);
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.d, required this.mine, required this.view, required this.onChanged});

  final PieceDetail d;

  /// The buyer's own queued or accepted request on this piece (spec 011).
  final BuyRequest? mine;
  final DetailView view;

  /// The listing changed (taken down): load it again.
  final VoidCallback onChanged;

  bool get _owner => view == DetailView.owner || d.own != null;
  bool get _cancelled => view == DetailView.cancelled;
  bool get _requested => view == DetailView.requested || view == DetailView.accepted || mine != null;

  Future<void> _share(BuildContext context) async {
    final ok = await ask(
      context,
      title: 'Share this piece',
      body: 'We will copy a link to the piece. Whoever opens it sees the photos, the weight and the price, but nothing about you.',
      yes: 'Copy the link',
    );
    if (ok && context.mounted) showToast(context, 'Link copied. It stays live while the piece is for sale.');
  }

  Future<void> _takeDown(BuildContext context) async {
    final own = d.own;
    if (own == null) {
      // A mock piece: nothing to call.
      final ok = await ask(
        context,
        title: 'Take this listing down',
        body: 'It stops showing to buyers. You can put it back up any time, and it keeps its history.',
        yes: 'Take it down',
      );
      if (ok && context.mounted) showToast(context, 'Taken down.');
      return;
    }
    final ok = await ask(
      context,
      title: 'Take this listing down',
      body: 'It stops showing to buyers and the listing is closed. This cannot be undone: to sell the piece later, list it again.',
      yes: 'Take it down',
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<ListingsRepository>().withdraw(own.id, idempotencyKey: newIdempotencyKey());
      if (context.mounted) showToast(context, 'Taken down.');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, listingErrorMessage(e));
    }
    onChanged();
  }

  Future<void> _leaveQueue(BuildContext context) async {
    final ok = await ask(
      context,
      title: 'Leave the queue?',
      body:
          'Your deposit comes back to your wallet in full. You can ask us to tell you if the piece later returns to the market with no requests on it, and send a fresh request then.',
      yes: 'Leave and notify me',
    );
    if (!ok || !context.mounted) return;
    final request = mine;
    if (request == null) {
      // A mock piece: nothing to call.
      showToast(context, 'You left the queue. Your deposit is back, and we will tell you if the piece is free again.');
      return context.nav(R.home);
    }
    try {
      await context.read<BuyRequestsRepository>().leave(request.id, notifyWhenFree: true, idempotencyKey: newIdempotencyKey());
      if (context.mounted) showToast(context, 'You left the queue. Your deposit is back, and we will tell you if the piece is free again.');
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, buyRequestErrorMessage(e));
    }
    onChanged();
  }

  /// Opens the video, the certificate or the invoice in a new browser tab.
  /// Market files are public and open by their address; the owner's own
  /// files need the session, so they are downloaded into the tab.
  Future<void> _openMedia(BuildContext context, String path) async {
    final client = context.read<ApiClient>();
    if (d.own == null) {
      if (MediaTab.open(client.mediaUri(path)) == null) showToast(context, 'The file could not be opened. Allow pop-ups for Dahab and try again.');
      return;
    }
    final tab = MediaTab.open();
    if (tab == null) return showToast(context, 'The file could not be opened. Allow pop-ups for Dahab and try again.');
    showToast(context, 'Opening…');
    try {
      final file = await client.getBytes(path, auth: true);
      tab.show(file.bytes, file.contentType);
    } on ApiException {
      tab.close();
      if (context.mounted) showToast(context, 'The file could not be loaded. Try again.');
    }
  }

  /// Send buy request (backend spec 011): the deposit terms, then the request with
  /// the exact price shown. A short wallet opens *You need a little more* with the
  /// backend's figures; a moved price reloads the piece with the new one.
  Future<void> _buy(BuildContext context) async {
    if (!context.read<AuthController>().isSignedIn) return context.nav(R.gate);
    final price = d.priceExact;
    if (!_uuid.hasMatch(d.piece.id) || price == null) {
      // A mock piece: the prototype's screen.
      return context.nav(R.reqsent);
    }
    final repo = context.read<BuyRequestsRepository>();
    final session = context.read<AppSession>();
    // A tap handler: read the language, never watch it.
    final arabic = context.read<LangController>().isArabic;
    final DepositTerms terms;
    try {
      terms = await repo.depositTerms();
    } on ApiException catch (e) {
      if (context.mounted) showToast(context, buyRequestErrorMessage(e));
      return;
    }
    if (!context.mounted) return;
    final ok = await ask(context, title: 'Before you send', body: arabic ? terms.bodyAr : terms.bodyEn, yes: 'Agree and send');
    if (!ok || !context.mounted) return;
    try {
      final request = await repo.send(listingId: d.piece.id, confirmedPrice: price, termsId: terms.id, idempotencyKey: newIdempotencyKey());
      session.requestSent(request);
      if (context.mounted) context.nav(R.reqsent);
    } on ApiException catch (e) {
      final short = shortfallOf(e);
      if (short != null) {
        session.walletShort(short);
        if (context.mounted) context.nav(R.topup);
        return;
      }
      if (!context.mounted) return;
      if (e.code == 'verification_required') return context.nav(R.gate);
      showToast(context, buyRequestErrorMessage(e));
      if (e.code == 'price_moved' || e.code == 'already_in_queue' || e.code == 'listing_not_purchasable') onChanged();
    }
  }

  /// The buyer's own request, in words (spec 011); the prototype's text for mock pieces.
  String _requestNote() {
    final r = mine;
    if (r == null) {
      return view == DetailView.accepted
          ? 'The seller accepted your request. Your deposit is held and the piece is on its way to IGI.'
          : 'Your request is in the queue. There is 1 buyer ahead of you. If the seller takes someone ahead of you, your deposit comes back in full at once.';
    }
    if (r.state == BuyRequestState.accepted) {
      final o = r.order;
      return o == null
          ? 'The seller accepted your request. Your deposit is held and the piece is on its way to IGI.'
          : 'The seller accepted your request (order ${o.orderRef}). Your deposit is held and the seller brings the piece to ${o.branchNameEn} by ${whenOf(o.reachBranchDeadline)}.';
    }
    final ahead = r.aheadCount ?? 0;
    final where = ahead == 0 ? 'You are next in line.' : (ahead == 1 ? 'There is 1 buyer ahead of you.' : 'There are $ahead buyers ahead of you.');
    return 'Your request is in the queue. $where The seller replies by ${whenOf(r.sellerReplyDeadline)}. If the seller takes someone ahead of you, declines, or does not reply in time, your deposit comes back in full at once.';
  }

  static String _stateLine(Listing l) => switch (l.state) {
    ListingState.draft => 'Not sent for approval yet',
    ListingState.inReview => 'Waiting for approval',
    ListingState.changesRequested => 'Changes needed',
    ListingState.live => 'Live',
    ListingState.reserved => 'Buyers in line',
    ListingState.accepted => 'Sold to a buyer, waiting for delivery',
    ListingState.rejected => 'Not accepted',
    ListingState.withdrawn => 'Taken down',
    ListingState.suspendedHold => 'On hold',
    ListingState.other => 'In progress',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final arabic = context.isArabic;
    final p = d.piece;
    final own = d.own;
    final queue = d.queueAhead ?? 0;
    final onMarket = own == null || own.state == ListingState.live;
    final branches = arabic && d.branchNamesAr.isNotEmpty ? d.branchNamesAr : d.branchNames;
    const rowPad = EdgeInsets.symmetric(vertical: 7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Gallery(d: d, auth: own != null),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_owner) ...[
                DCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const DIcon('tag', size: 17, color: DColors.gold),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const T('This is your listing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                if (own != null) T(_stateLine(own), style: DText.tiny) else if (!d.live) const T('84 views, 2 buyers in the queue', style: DText.tiny),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (own != null && own.state == ListingState.reserved) ...[const Gap(10), _SellerQueueCard(listing: own, onChanged: onChanged)],
                      if (own?.order != null) ...[const Gap(10), _OrderNote(order: own!.order!)],
                      if (own?.staffMessage?.isNotEmpty ?? false) ...[
                        const Gap(10),
                        DSoft.paper(
                          child: T(own!.staffMessage!, style: DText.tiny.copyWith(color: DColors.ink2, height: 1.65)),
                        ),
                      ],
                      const Gap(10),
                      DActsRow(
                        children: [
                          if (!d.live) MockMark(child: DButton.ghost('Change fee', small: true, onTap: () => context.nav(R.editprice))),
                          if (own != null && own.canEdit)
                            DButton.ghost(
                              'Fix and resend',
                              small: true,
                              onTap: () {
                                context.read<SellDraft>().loadFrom(own);
                                context.nav(R.sell1);
                              },
                            ),
                          if (own == null ? !d.live : own.canWithdraw) DButton.ghost('Take down', small: true, onTap: () => _takeDown(context)),
                          DButton.ghost('View', small: true, onTap: () => context.nav(R.listings)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(14),
              ],
              if (p.priceAvailable) ...[
                T(money(p.price), style: DText.price.copyWith(fontSize: 24)),
                const Gap(4),
                T(p.priceIndicative ? 'The price moves with the gold rate until you send a request.' : 'Set price', style: DText.tiny),
                if (d.depositExact != null && !_owner && !p.mine) ...[const Gap(4), T('Deposit needed to send a request: ${moneyOf(d.depositExact)}', style: DText.tiny)],
              ] else
                const T('Price not available right now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (own?.youWouldReceive != null) ...[
                const Gap(6),
                T('You would receive ${money(double.tryParse(own!.youWouldReceive!) ?? 0)}', style: DText.tiny.copyWith(color: DColors.ok)),
              ],
              const Gap(12),
              if (queue > 0 && !d.live) ...[
                const DNote(
                  icon: 'users',
                  text: '2 buyers are already in the queue for this piece. If you send a request you join the queue, and the seller answers requests in the order they arrived.',
                ),
                const Gap(12),
              ],
              if (d.views != null) ...[
                _StatRow(stats: [('${d.views}', 'people viewed'), ('${d.requests}', 'asked to buy'), ('${d.daysListed}', 'days listed')]),
                const Gap(14),
              ],
              if (p.priceAvailable && d.goldValue != null) ...[
                DSoft.bordered(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DRow('Gold, ${p.weight.toStringAsFixed(2)} g at ${group(d.goldRate ?? 0)}', money(d.goldValue!)),
                      if (p.makingPerGram != null)
                        DRow('Making charge, ${p.makingPerGram} per gram', money(d.makingValue ?? 0))
                      else
                        DRow('Stone and making charge', money(p.price > d.goldValue! ? p.price - d.goldValue! : 0)),
                      if (p.makingPerGram != null && d.commission != null) DRow('Commission, VAT included', money(d.commission!)),
                      DRow('Total', money(p.price), rule: true, bold: true, keyIsLabel: false),
                      if (d.deposit != null && !d.live) ...[
                        const Gap(7),
                        T('Deposit needed to send a request: ${group(d.deposit!)} EGP', style: DText.tiny),
                        const Gap(5),
                        T(
                          "If you don't pay the balance after the piece is inspected and ready, you lose the deposit, and half of it goes to the seller as compensation.",
                          style: DText.tiny.copyWith(color: DColors.wait),
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(10),
                T('Priced at the Dahab buy rate for ${p.karat}K, taken from the live exchange rate.', style: DText.tiny),
                const Gap(14),
              ],
              const DLabel('Specifications'),
              if (p.karat > 0) DRow('Karat', '${p.karat}K', bottomBorder: true, padding: rowPad),
              if (p.weight > 0) DRow('Weight', '${p.weight.toStringAsFixed(2)} g', bottomBorder: true, padding: rowPad),
              DRow('Type', _kindLabel(p.kind), bottomBorder: true, padding: rowPad),
              if (d.hasVideo)
                DRow(
                  'Video',
                  '',
                  bottomBorder: true,
                  padding: rowPad,
                  valueWidget: DLink('Watch the video', onTap: () => _openMedia(context, d.videoPath!)),
                ),
              if (d.hasCertificate)
                DRow(
                  'Stone certificate',
                  '',
                  bottomBorder: true,
                  padding: rowPad,
                  valueWidget: DLink('Open the certificate', onTap: () => _openMedia(context, d.certificatePath!)),
                ),
              if (d.invoicePath != null)
                DRow(
                  'Invoice',
                  '',
                  bottomBorder: true,
                  padding: rowPad,
                  valueWidget: DLink('Open the invoice', onTap: () => _openMedia(context, d.invoicePath!)),
                ),
              if (d.invoicePath != null)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: T('Only you and Dahab can see the invoice. The buyer gets it after the sale.', style: DText.tiny),
                ),
              if (d.origin != null)
                DRow(
                  'Origin',
                  '',
                  padding: rowPad,
                  valueWidget: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: context.t(d.origin!)),
                        const TextSpan(text: ' '),
                        TextSpan(text: context.t('(stated by seller)'), style: DText.tiny),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const Gap(14),
              if (d.description.isNotEmpty) ...[const DLabel("Seller's description"), T(d.description, style: DText.muted), const Gap(14)],
              if (branches.isNotEmpty) ...[
                const DLabel('Where it can be inspected'),
                for (final b in branches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const DIcon('map-pin', size: 14, color: DColors.ink3),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b, style: DText.muted12)),
                      ],
                    ),
                  ),
                const Gap(10),
              ],
              if (d.sellerName != null) ...[
                DSoft.bordered(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(color: DColors.paper, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const DIcon('user-check', size: 15, color: DColors.gold),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          T(d.sellerName!, style: DText.body13),
                          const T('Identity verified', style: DText.tiny),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(14),
              ],
              if (onMarket) ...[
                const DNote(icon: 'clock', kind: NoteKind.wait, text: 'This piece has not been inspected yet. It goes to IGI once the seller accepts your request.'),
                const Gap(14),
                const DNote(
                  icon: 'shield-check',
                  kind: NoteKind.ok,
                  text:
                      "You only pay the balance after IGI confirms the karat, weight and condition match this listing. If they don't, you can walk away and your deposit comes back.",
                ),
                const Gap(16),
                DButton.ghost('Share this piece', small: true, expand: true, onTap: () => _share(context)),
                const Gap(12),
              ],
              if (!_owner && !_cancelled) ...[
                Center(
                  child: MockMark(child: DLink('Report this listing', style: DText.tiny, onTap: () => context.nav(R.report))),
                ),
                const Gap(14),
              ],
              if (_requested && !_owner && !_cancelled) ...[
                DNote(icon: 'clock', kind: NoteKind.wait, text: _requestNote()),
                const Gap(12),
                DButton.ghost('Follow your order', onTap: () => context.nav(R.orders)),
                if (view == DetailView.requested || mine?.state == BuyRequestState.queued) ...[
                  const Gap(10),
                  Center(
                    child: DLink('Leave the queue and get my deposit back', style: DText.tiny, onTap: () => _leaveQueue(context)),
                  ),
                ],
              ],
              if (_cancelled) const DNote(icon: 'info-circle', text: 'This listing is closed. It is here for your records only and cannot be bought.'),
              if (!_owner && !_cancelled && !_requested && !p.mine) ...[
                if (queue > 0) ...[
                  DNote(
                    icon: 'users',
                    text: queue == 1
                        ? '1 buyer is already in the queue for this piece. The seller takes them in order, so you would be next after them.'
                        : '$queue buyers are already in the queue for this piece. The seller takes them in order, so you would be next after them.',
                  ),
                  const Gap(12),
                ],
                DActsRow(
                  children: [
                    DButton('Send buy request', onTap: p.priceAvailable || !d.live ? () => _buy(context) : null),
                    MockMark(
                      child: DButton.ghost(
                        session.savedPiece ? 'Saved' : 'Save',
                        small: true,
                        foreground: session.savedPiece ? DColors.gold : null,
                        borderColor: session.savedPiece ? DColors.gold : null,
                        onTap: () {
                          session.toggleSavedPiece();
                          showToast(context, session.savedPiece ? 'Added to your saved pieces.' : 'Removed from saved.');
                        },
                      ),
                    ),
                  ],
                ),
                const Gap(9),
                const Center(
                  child: T('The price is fixed once the seller accepts your request.', style: DText.tiny, textAlign: TextAlign.center),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The photos, swiped side to side, with the "1 of 5" counter.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.d, required this.auth});

  final PieceDetail d;

  /// The owner's own media needs their session; market photos do not.
  final bool auth;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final paths = d.photoPaths;
    final count = paths.isEmpty ? d.photoCount : paths.length;
    final video = d.live ? d.hasVideo : true;
    return Stack(
      children: [
        if (paths.isEmpty)
          const PieceThumb(height: 170, iconSize: 38)
        else
          SizedBox(
            height: 170,
            child: PageView(
              onPageChanged: (i) => setState(() => _index = i),
              children: [for (final p in paths) ApiImage(path: p, auth: widget.auth, height: 170, iconSize: 38)],
            ),
          ),
        if (count > 0)
          PositionedDirectional(
            bottom: 11,
            end: 13,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
              decoration: BoxDecoration(color: DColors.white, borderRadius: BorderRadius.circular(999)),
              child: T(video ? '${_index + 1} of $count, plus video' : '${_index + 1} of $count', style: DText.tiny),
            ),
          ),
      ],
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
  'ring' => 'Ring',
  'bracelet' => 'Bracelet',
  'bangle' => 'Bangle',
  'earrings' => 'Earrings',
  'necklace' => 'Necklace',
  'chain' => 'Chain',
  'pendant' => 'Pendant',
  'bridal set' => 'Bridal set',
  _ => kind.isEmpty ? 'Other' : '${kind[0].toUpperCase()}${kind.substring(1)}',
};

/// `.statrow` — three numbers with captions, split by hairlines.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DColors.white,
        border: Border.all(color: DColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: DColors.line),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Column(
                    children: [
                      T(stats[i].$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      T(
                        stats[i].$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: DColors.ink3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The line on the seller's own piece (backend spec 011): the first buyer in line,
/// with Accept (at one of the branches named for the piece) and Decline.
class _SellerQueueCard extends StatefulWidget {
  const _SellerQueueCard({required this.listing, required this.onChanged});

  final Listing listing;
  final VoidCallback onChanged;

  @override
  State<_SellerQueueCard> createState() => _SellerQueueCardState();
}

class _SellerQueueCardState extends State<_SellerQueueCard> {
  late Future<SellerQueue> _future = context.read<BuyRequestsRepository>().queue(widget.listing.id);
  bool _busy = false;

  Future<void> _accept(SellerQueueItem head) async {
    final l = widget.listing;
    final arabic = context.read<LangController>().isArabic;
    final branchId = await showDialog<int>(
      context: context,
      barrierColor: DColors.modalBarrier,
      builder: (ctx) => SimpleDialog(
        title: const T('Choose where to take the piece', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: T('Your deadline is counted in working hours at the branch you pick.', style: DText.tiny),
          ),
          for (var i = 0; i < l.branchIds.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(l.branchIds[i]),
              child: Text(arabic && i < l.branchNamesAr.length ? l.branchNamesAr[i] : (i < l.branchNames.length ? l.branchNames[i] : '#${l.branchIds[i]}')),
            ),
        ],
      ),
    );
    if (branchId == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final order = await context.read<BuyRequestsRepository>().accept(l.id, head.id, branchId, idempotencyKey: newIdempotencyKey());
      if (mounted) showToast(context, 'Accepted. Bring the piece to ${order.branchNameEn} by ${whenOf(order.reachBranchDeadline)}.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, buyRequestErrorMessage(e));
    }
    if (mounted) setState(() => _busy = false);
    widget.onChanged();
  }

  Future<void> _decline(SellerQueueItem head) async {
    final ok = await ask(
      context,
      title: 'Decline this request',
      body: "The buyer's deposit is released at once. The next buyer in line, if there is one, becomes the first; otherwise the piece is back on the market.",
      yes: 'Decline',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<BuyRequestsRepository>().decline(widget.listing.id, head.id, idempotencyKey: newIdempotencyKey());
      if (mounted) showToast(context, 'Declined. The buyer has their deposit back.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, buyRequestErrorMessage(e));
    }
    if (mounted) setState(() => _busy = false);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SellerQueue>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return DLink(
            'The buy requests could not be loaded. Try again.',
            style: DText.tiny,
            onTap: () => setState(() {
              _future = context.read<BuyRequestsRepository>().queue(widget.listing.id);
            }),
          );
        }
        final q = snap.data;
        if (q == null) return const DLoading(height: 60);
        final head = q.head;
        if (head == null) return const T('Nobody is in line right now.', style: DText.tiny);
        return DSoft.bordered(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T(q.items.length == 1 ? '1 buyer in line' : '${q.items.length} buyers in line', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Gap(6),
              DRow('A buy request at', moneyOf(head.lockedTotalPrice)),
              DRow('From buyer', head.buyerRef),
              if (q.youWouldReceive != null) DRow('You would receive', moneyOf(q.youWouldReceive)),
              DRow('Reply before', whenOf(head.sellerReplyDeadline), valueColor: DColors.bad),
              const Gap(8),
              const T("If you accept, the price is fixed and you have 12 working hours to reach the branch. If you decline, the buyer's deposit is released.", style: DText.tiny),
              const Gap(10),
              DActsRow(
                children: [
                  DButton('Accept', small: true, onTap: _busy ? null : () => _accept(head)),
                  DButton.ghost('Decline', small: true, onTap: _busy ? null : () => _decline(head)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The sale on the seller's piece (spec 011): accepted, or cancelled by Dahab.
class _OrderNote extends StatelessWidget {
  const _OrderNote({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    if (order.cancelled) {
      return DNote(
        icon: 'info-circle',
        text: 'Dahab cancelled sale ${order.orderRef}: ${order.cancelReason ?? ''} The buyer had their deposit back. This does not count against you.',
      );
    }
    return DNote(
      icon: 'clock',
      kind: NoteKind.wait,
      text: 'You accepted a buyer (order ${order.orderRef}). Bring the piece to ${order.branchNameEn} by ${whenOf(order.reachBranchDeadline)}.',
    );
  }
}
