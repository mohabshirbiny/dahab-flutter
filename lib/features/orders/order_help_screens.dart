import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../models/dispute.dart';
import '../../models/order.dart';
import '../../models/piece.dart';
import '../../models/reference.dart';
import '../../services/api/api_client.dart';
import '../../services/api/orders_api.dart';
import '../../services/auth/auth_messages.dart' show toE164;
import '../../services/media_picker.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import 'order_flows.dart' show OrderContextCard;

// Backend spec 014, on the live API: report a problem (`#s-dispute`), ask for more
// time (`#s-extend`) and someone else collects (`#s-proxy`). Each opens on one
// order (`?id=`); the backend says which of them apply (`actions`) and re-checks.

/// Loads the order the screen is about, then builds the form.
class _OnOrder extends StatefulWidget {
  const _OnOrder({required this.id, required this.screenId, required this.builder});

  final String id;
  final String screenId;
  final Widget Function(BuildContext context, CustomerOrder order) builder;

  @override
  State<_OnOrder> createState() => _OnOrderState();
}

class _OnOrderState extends State<_OnOrder> {
  CustomerOrder? _order;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    if (widget.id.isEmpty) return;
    try {
      final o = await context.read<OrdersRepository>().show(widget.id);
      if (mounted) setState(() => _order = o);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return AppPage(
      id: widget.screenId,
      child: widget.id.isEmpty
          ? DEmpty(
              icon: 'package',
              title: 'Open the order first',
              body: 'This is done from the order it is about.',
              action: 'See your orders',
              onAction: () => context.nav(R.orders),
            )
          : (o != null ? widget.builder(context, o) : (_failed ? DErrorState(onRetry: _load) : const DLoading(height: 300))),
    );
  }
}

String _title(BuildContext context, CustomerOrder o) =>
    context.isArabic && o.typeNameAr.isNotEmpty ? pieceTitleAr(o.category, o.typeNameAr, o.karat) : pieceTitle(o.category, o.typeNameEn, o.karat);

/// One idempotency key per form, kept while the same thing is retried.
mixin _Keyed<W extends StatefulWidget> on State<W> {
  String? _key;
  String get key => _key ??= newIdempotencyKey();
  void forgetKey() => _key = null;
}

/// `#s-dispute` — report a problem with an order. The order freezes at once.
class DisputeScreen extends StatelessWidget {
  const DisputeScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) => _OnOrder(
    id: orderId,
    screenId: R.dispute,
    builder: (context, o) => _DisputeForm(key: ValueKey(o.id), order: o),
  );
}

class _DisputeForm extends StatefulWidget {
  const _DisputeForm({super.key, required this.order});

  final CustomerOrder order;

  @override
  State<_DisputeForm> createState() => _DisputeFormState();
}

class _DisputeFormState extends State<_DisputeForm> with _Keyed {
  static const _maxPhotos = 5;

  String? _reason;
  final _text = TextEditingController();
  final _photos = <String>[];
  bool _error = false;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_uploading || _photos.length >= _maxPhotos) return;
    final picked = await context.read<MediaPicker>().pick(MediaKind.disputePhoto);
    if (picked == null || !mounted) return;
    if (picked.file == null) return showToast(context, picked.error!);
    setState(() => _uploading = true);
    try {
      final token = await context.read<OrdersRepository>().upload(MediaKind.disputePhoto, picked.file!);
      if (!mounted) return;
      setState(() => _photos.add(token));
      forgetKey();
      showToast(context, 'Added.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.isNetwork ? orderErrorMessage(e) : 'The photo could not be added. Use a JPG, PNG or WEBP under 8 MB.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    final detail = _text.text.trim();
    if (_reason == null || detail.length < 10) return setState(() => _error = true);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = await context.read<OrdersRepository>().openDispute(widget.order.id, reason: _reason!, detail: detail, photoTokens: List.of(_photos), idempotencyKey: key);
      forgetKey();
      if (!mounted) return;
      await tell(context, title: 'We have it', body: 'The order is on hold and someone will be in touch today. Your reference is ${d.ref}.');
      if (mounted) context.nav(R.order, query: {'id': widget.order.id});
    } on ApiException catch (e) {
      if (!e.isNetwork) forgetKey();
      if (mounted) showToast(context, orderErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final reasons = [
      for (final r in disputeReasons)
        if (!o.isSeller || !buyerOnlyDisputeReasons.contains(r.$1)) r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderContextCard(_title(context, o), 'Order ${o.orderRef}', padding: 13),
        const Gap(16),
        if (!o.can('report_problem'))
          DNote(
            icon: 'info-circle',
            kind: NoteKind.wait,
            text: o.dispute != null
                ? 'You already reported a problem on this order.'
                : 'A problem can be reported only while the piece is at inspection, or waiting to be paid for or collected.',
          )
        else ...[
          const DLabel('What went wrong?'),
          DChoiceList<String>(
            value: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              _error = false;
              forgetKey();
            }),
            options: [for (final r in reasons) ChoiceOption(r.$1, r.$2)],
          ),
          const Gap(14),
          const DLabel('Tell us what happened'),
          DInput(
            controller: _text,
            maxLines: 4,
            hint: 'Dates, amounts, anything you noticed. The more detail the faster we can sort it.',
            onChanged: (_) => setState(() {
              _error = false;
              forgetKey();
            }),
          ),
          const Gap(14),
          const DLabel('Anything to show us'),
          for (var i = 0; i < _photos.length; i++) ...[
            DSlot(
              title: 'Photo ${i + 1}',
              sub: 'Added',
              subColor: DColors.ok,
              icon: 'camera',
              boxHeight: 50,
              iconSize: 20,
              done: true,
              onTap: () => setState(() {
                _photos.removeAt(i);
                forgetKey();
              }),
            ),
            const Gap(8),
          ],
          if (_photos.length < _maxPhotos)
            DSlot(title: _uploading ? 'Uploading…' : 'Add a photo', sub: 'Optional, up to 5', icon: 'camera', boxHeight: 50, iconSize: 20, done: false, onTap: _addPhoto),
          const Gap(14),
          const DNote(icon: 'lock', text: 'The order is frozen while we look at it. No money moves and no deadline runs against you.'),
          const Gap(14),
          DError('Choose what went wrong and write a line or two.', visible: _error, top: 0),
          if (_error) const Gap(7),
          DButton('Send to Dahab', loading: _busy, onTap: _uploading ? null : _send),
        ],
      ],
    );
  }
}

/// `#s-extend` — the seller asks for more time to bring the piece to the branch.
class ExtendScreen extends StatelessWidget {
  const ExtendScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) => _OnOrder(
    id: orderId,
    screenId: R.extend,
    builder: (context, o) => _ExtendForm(key: ValueKey(o.id), order: o),
  );
}

class _ExtendForm extends StatefulWidget {
  const _ExtendForm({super.key, required this.order});

  final CustomerOrder order;

  @override
  State<_ExtendForm> createState() => _ExtendFormState();
}

class _ExtendFormState extends State<_ExtendForm> with _Keyed {
  String? _reason;
  final _text = TextEditingController();
  bool _error = false;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _sold => _reason == 'sold';

  Future<void> _send() async {
    if (_busy) return;
    final o = widget.order;
    if (_sold) {
      // "I already sold it elsewhere" is not a request for time: it cancels the sale.
      final ok = await ask(
        context,
        title: 'Cancel the sale',
        body: 'This cancels the sale, it does not extend it. The buyer gets their deposit back in full, and the cancellation is counted on your account.',
        yes: 'Cancel the sale',
      );
      if (!ok || !mounted) return;
      setState(() => _busy = true);
      try {
        await context.read<OrdersRepository>().cancel(o.id, idempotencyKey: key);
        forgetKey();
        if (!mounted) return;
        showToast(context, 'The sale is cancelled.');
        context.nav(R.order, query: {'id': o.id});
      } on ApiException catch (e) {
        if (!e.isNetwork) forgetKey();
        if (mounted) showToast(context, orderErrorMessage(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final detail = _text.text.trim();
    if (_reason == null || detail.length < 10) return setState(() => _error = true);
    setState(() => _busy = true);
    try {
      await context.read<OrdersRepository>().requestMoreTime(o.id, reason: _reason!, detail: detail, idempotencyKey: key);
      forgetKey();
      if (!mounted) return;
      showToast(context, 'Request sent. We will answer within the hour.');
      context.nav(R.order, query: {'id': o.id});
    } on ApiException catch (e) {
      if (!e.isNetwork) forgetKey();
      if (mounted) showToast(context, orderErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final deadline = o.deadline;
    final left = deadline?.at.difference(DateTime.now());
    final sub = deadline == null
        ? 'Order ${o.orderRef}'
        : 'Bring it by ${whenOf(deadline.at)}${left == null || left.isNegative ? '' : ' · ${left.inHours} h ${left.inMinutes % 60} min left'}';
    final canAsk = o.can('ask_more_time');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderContextCard(_title(context, o), sub),
        const Gap(16),
        if (!canAsk && o.extensionRequest?.state == 'waiting')
          const DNote(icon: 'clock', kind: NoteKind.wait, text: 'You already asked for more time. We will answer soon.')
        else if (!canAsk && !o.can('cancel'))
          const DNote(icon: 'info-circle', kind: NoteKind.wait, text: 'More time can be asked only while you are bringing the piece, before the deadline.')
        else ...[
          const DLabel('Why do you need more time?'),
          DChoiceList<String>(
            value: _reason,
            onChanged: (v) => setState(() {
              _reason = v;
              _error = false;
              forgetKey();
            }),
            options: [
              if (canAsk)
                for (final r in extensionReasons) ChoiceOption(r.$1, r.$2),
              if (o.can('cancel')) const ChoiceOption('sold', 'I already sold it elsewhere', 'This cancels the sale, it does not extend it'),
            ],
          ),
          if (!_sold) ...[
            const Gap(14),
            const DLabel('Tell us briefly'),
            DInput(
              controller: _text,
              maxLines: 3,
              hint: 'A sentence is enough.',
              onChanged: (_) => setState(() {
                _error = false;
                forgetKey();
              }),
            ),
          ],
          DError('Choose a reason and write a line before sending.', visible: _error),
          const Gap(15),
          if (_sold)
            const DNote(
              icon: 'alert-triangle',
              iconColor: DColors.bad,
              textStyle: TextStyle(color: DColors.bad),
              text: "Cancelling after a buyer accepted counts against your account. Two of these and you cannot list for a while. The buyer's deposit is released straight away.",
            )
          else
            const DNote(icon: 'clock', kind: NoteKind.wait, text: "The buyer's price stays locked while we review this. Requests are usually answered within an hour."),
          const Gap(15),
          DButton(_sold ? 'Cancel the sale' : 'Send request', loading: _busy, onTap: _send),
        ],
      ],
    );
  }
}

/// `#s-proxy` — the buyer names someone else to collect the piece.
class ProxyScreen extends StatelessWidget {
  const ProxyScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) => _OnOrder(
    id: orderId,
    screenId: R.proxy,
    builder: (context, o) => _ProxyForm(key: ValueKey(o.id), order: o),
  );
}

class _ProxyForm extends StatefulWidget {
  const _ProxyForm({super.key, required this.order});

  final CustomerOrder order;

  @override
  State<_ProxyForm> createState() => _ProxyFormState();
}

class _ProxyFormState extends State<_ProxyForm> with _Keyed {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _idToken;
  LegalDoc? _terms;
  bool _ok = false;
  bool _error = false;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final doc = await context.read<OrdersRepository>().proxyAuthorisation();
      if (mounted) setState(() => _terms = doc);
    } on Object {
      // Sending without the terms is refused below; the customer can come back.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// "+44 7700 900123" stays as typed; a local number is Egyptian.
  String get _e164 {
    final raw = _phone.text.trim();
    return raw.startsWith('+') ? '+${raw.replaceAll(RegExp(r'\D'), '')}' : toE164('+20', raw);
  }

  Future<void> _addId() async {
    if (_uploading) return;
    final picked = await context.read<MediaPicker>().pick(MediaKind.proxyId);
    if (picked == null || !mounted) return;
    if (picked.file == null) return showToast(context, picked.error!);
    setState(() => _uploading = true);
    try {
      final token = await context.read<OrdersRepository>().upload(MediaKind.proxyId, picked.file!);
      if (!mounted) return;
      setState(() {
        _idToken = token;
        _error = false;
      });
      forgetKey();
      showToast(context, 'Added.');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.isNetwork ? orderErrorMessage(e) : 'The photo could not be added. Use a JPG, PNG or WEBP under 8 MB.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _send() async {
    final name = _name.text.trim();
    final terms = _terms;
    if (name.length < 2 || !RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(_e164) || _idToken == null || !_ok || terms == null) {
      return setState(() => _error = true);
    }
    if (_busy) return;
    setState(() {
      _error = false;
      _busy = true;
    });
    try {
      await context.read<OrdersRepository>().nameProxy(widget.order.id, name: name, phone: _e164, idToken: _idToken!, authorisationId: terms.id, idempotencyKey: key);
      forgetKey();
      if (!mounted) return;
      await tell(context, title: 'Code sent', body: 'They will get the collection code on their number. The branch checks their ID against it at the counter.');
      if (mounted) context.nav(R.order, query: {'id': widget.order.id});
    } on ApiException catch (e) {
      if (!e.isNetwork) forgetKey();
      if (e.code == 'upload_token_invalid' && mounted) setState(() => _idToken = null);
      if (mounted) showToast(context, orderErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await ask(
      context,
      title: 'Collect it yourself',
      body: 'The person you named can no longer collect the piece. Only you can, with your own code.',
      yes: 'Remove them',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<OrdersRepository>().removeProxy(widget.order.id, idempotencyKey: key);
      forgetKey();
      if (!mounted) return;
      showToast(context, 'Removed. Only you can collect it now.');
      context.nav(R.order, query: {'id': widget.order.id});
    } on ApiException catch (e) {
      if (!e.isNetwork) forgetKey();
      if (mounted) showToast(context, orderErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final proxy = o.proxy;
    final terms = _terms;
    if (!o.can('name_proxy')) {
      return const DNote(icon: 'info-circle', kind: NoteKind.wait, text: 'Someone else can be named once the piece is paid for and waiting at the branch.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const T("Can't get to the branch yourself? Someone you trust can collect the piece for you.", style: DText.muted),
        const Gap(16),
        if (proxy != null) ...[
          DSoft.bordered(
            child: Column(children: [DRow('Collecting now', proxy.name), DRow('Their phone', proxy.phoneMasked), if (proxy.namedAt != null) DRow('Named', whenOf(proxy.namedAt!))]),
          ),
          const Gap(10),
          DButton.ghost('Collect it myself instead', loading: _busy, onTap: _remove),
          const Gap(16),
          const DLabel('Name someone else instead'),
        ] else
          const DLabel('Who is collecting'),
        DField(
          label: 'Full name, as written on their ID',
          child: DInput(controller: _name, hint: 'Their full name', onChanged: (_) => forgetKey()),
        ),
        DField(
          label: 'Their phone number',
          child: DInput(controller: _phone, hint: '+20 10 0000 0000', keyboardType: TextInputType.phone, onChanged: (_) => forgetKey()),
        ),
        const DLabel('A photo of their ID'),
        DSlot(
          title: 'Front of their ID',
          sub: _uploading ? 'Uploading…' : (_idToken != null ? 'Added' : 'The branch checks it against the person at the counter'),
          subColor: _idToken != null ? DColors.ok : null,
          icon: 'camera',
          done: _idToken != null,
          onTap: _addId,
        ),
        const Gap(12),
        const DNote(
          icon: 'alert-triangle',
          kind: NoteKind.wait,
          text: 'Dahab does not verify the relationship between you. Choosing this person is your decision, and the piece is handed over once their ID and the code match.',
        ),
        const Gap(14),
        DCheck(
          value: _ok,
          bottom: 14,
          onChanged: (v) => setState(() => _ok = v),
          text: terms == null
              ? 'I authorise this person to collect the piece on my behalf, and I take responsibility for that choice.'
              : (context.isArabic && terms.bodyAr.isNotEmpty ? terms.bodyAr : terms.bodyEn),
        ),
        DError('Fill in their name, a valid phone and their ID photo, and tick the box.', visible: _error, top: 0),
        if (_error) const Gap(7),
        DButton('Send them the collection code', loading: _busy, onTap: _uploading ? null : _send),
      ],
    );
  }
}
