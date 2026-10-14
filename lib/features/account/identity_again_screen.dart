import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/account_identity.dart';
import '../../core/text/texts_controller.dart';
import '../../models/customer.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../services/media_picker.dart';
import '../../widgets/widgets.dart';
import '../shared/suspended_notice.dart';

/// The pill that says where the identity check stands (backend testing fixes, item 4). The same
/// four words everywhere: Verified / Waiting for review / Upload again / Not approved.
class IdentityPill extends StatelessWidget {
  const IdentityPill(this.customer, {super.key});

  final CustomerProfile customer;

  @override
  Widget build(BuildContext context) {
    final v = customer.verification;
    // An older backend without `verification`: fall back on the account status.
    if (customer.isVerified || v.isVerified) return DPill(context.k(AccountIdentityKeys.pillVerified));
    if (v.isUploadAgain) return DPill(context.k(AccountIdentityKeys.pillUploadAgain), kind: PillKind.bad);
    if (v.isRejected || customer.status == 'rejected') return DPill(context.k(AccountIdentityKeys.pillNotApproved), kind: PillKind.bad);
    if (v.documentStatus == null && v.canSubmit) return DPill(context.k(AccountIdentityKeys.pillMissing), kind: PillKind.wait);
    return DPill(context.k(AccountIdentityKeys.pillWaiting), kind: PillKind.wait);
  }
}

/// The reviewer's reasons and note, as the customer reads them.
class IdentityReasons extends StatelessWidget {
  const IdentityReasons(this.verification, {super.key});

  final CustomerVerification verification;

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (final r in verification.reasons)
        if (AccountIdentityKeys.reason(r) case final key?) context.k(key),
    ];
    final note = verification.note?.trim() ?? '';
    if (labels.isEmpty && note.isEmpty) return const SizedBox.shrink();
    return DCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labels.isNotEmpty) ...[
            Text(context.k(AccountIdentityKeys.whatWasWrong), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Gap(4),
            for (final l in labels) Text('• $l', style: DText.body13),
          ],
          if (note.isNotEmpty) ...[
            if (labels.isNotEmpty) const Gap(8),
            Text(context.k(AccountIdentityKeys.noteFromDahab), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Gap(4),
            Text(note, style: DText.body13),
          ],
        ],
      ),
    );
  }
}

/// Stands in for the sell form until the account may trade (backend testing fixes, item 6): the
/// backend refuses a listing for an account that is not active (`customer.gate:trade`), so the
/// customer is told before filling three steps, with the one thing they can do about it.
/// Returns null when selling is open.
Widget? sellGate(BuildContext context, CustomerProfile? me) {
  if (me == null || me.tradeAllowed || me.status == 'active') return null;
  if (me.status == 'suspended') {
    return const Padding(padding: EdgeInsets.only(top: 6), child: SuspendedNotice());
  }
  if (me.status == 'closed') {
    return _GateCard(title: context.k(AccountIdentityKeys.sellClosedTitle), body: '', icon: 'lock');
  }
  final v = me.verification;
  if (v.canSubmit) {
    return _GateCard(
      title: context.k(AccountIdentityKeys.sellAgainTitle),
      body: context.k(AccountIdentityKeys.sellAgainBody),
      icon: 'shield-lock',
      verification: v,
      action: DButton(context.k(AccountIdentityKeys.title), onTap: () => context.nav(R.idAgain)),
    );
  }
  return _GateCard(title: context.k(AccountIdentityKeys.sellWaitingTitle), body: context.k(AccountIdentityKeys.sellWaitingBody), icon: 'clock');
}

class _GateCard extends StatelessWidget {
  const _GateCard({required this.title, required this.body, required this.icon, this.verification, this.action});

  final String title;
  final String body;
  final String icon;
  final CustomerVerification? verification;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      children: [
        DIcon(icon, size: 34, color: DColors.gold),
        const Gap(14),
        Text(title, style: DText.h2, textAlign: TextAlign.center),
        if (body.isNotEmpty) ...[const Gap(6), Text(body, style: DText.muted, textAlign: TextAlign.center)],
        if (verification != null) ...[const Gap(16), IdentityReasons(verification!)],
        if (action != null) ...[const Gap(16), action!],
      ],
    ),
  );
}

/// "Upload your ID again" (backend testing fixes, item 5): the reviewer's reasons and note, the
/// Egyptian ID (front + back) or a passport (photo page, another page optional), each photo sent
/// with `POST /customer/me/uploads` (`purpose=identity`), then a new attempt with
/// `POST /customer/me/identity-documents`. Reached from the National ID row of Account and from
/// the inbox items `account.resubmission_requested` / `account.verification_rejected`.
class IdentityAgainScreen extends StatefulWidget {
  const IdentityAgainScreen({super.key});

  @override
  State<IdentityAgainScreen> createState() => _IdentityAgainScreenState();
}

class _IdentityAgainScreenState extends State<IdentityAgainScreen> {
  String? _doc;
  UploadFile? _front;
  UploadFile? _back;
  String? _error;
  bool _busy = false;
  bool _sent = false;

  bool get _passport => _doc == 'passport';

  Future<void> _pick(bool front) async {
    final picked = await context.read<MediaPicker>().pick(MediaKind.identity);
    if (picked == null || !mounted) return;
    if (picked.error != null) return showToast(context, picked.error!);
    setState(() {
      final file = picked.file!;
      final named = UploadFile(field: 'file', filename: file.filename, bytes: file.bytes, contentType: file.contentType);
      front ? _front = named : _back = named;
      _error = null;
    });
  }

  Future<void> _send() async {
    if (_front == null || (!_passport && _back == null)) return setState(() => _error = context.kr(AccountIdentityKeys.photosMissing));
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthController>().resubmitIdentity(docKind: _doc!, front: _front!, back: _back);
      if (!mounted) return;
      setState(() => _sent = true);
      showToast(context, context.kr(AccountIdentityKeys.sent));
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'document_already_pending' => context.kr(AccountIdentityKeys.alreadyPending),
        'upload_token_invalid' => context.kr(AccountIdentityKeys.uploadExpired),
        'unsupported_doc_kind' => context.kr(AccountIdentityKeys.unsupportedKind),
        _ => e.fieldError('front_upload_token') ?? e.fieldError('file') ?? authErrorMessage(e),
      };
      if (e.code == 'document_already_pending') await context.read<AuthController>().refreshVerification(force: true);
      if (!mounted) return;
      setState(() {
        _error = message;
        if (e.code == 'upload_token_invalid') _front = _back = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _slot(String title, UploadFile? file, bool front) => DSlot(
    title: title,
    done: file != null,
    sub: file != null ? context.k(AccountIdentityKeys.added) : context.k(AccountIdentityKeys.tapToAdd),
    subColor: file != null ? DColors.ok : null,
    footer: file != null ? [const Gap(2), Text(file.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: DText.tiny)] : null,
    onTap: () => _pick(front),
  );

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().customer;
    final v = me?.verification ?? CustomerVerification.none;
    _doc ??= v.docKind ?? 'egyptian_id';

    return AppPage(
      id: R.idAgain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sent || (me != null && !v.canSubmit)) ...[
            DNote(icon: 'clock', kind: NoteKind.wait, text: context.k(_sent ? AccountIdentityKeys.sent : AccountIdentityKeys.notNeeded)),
            const Gap(14),
            Center(child: IdentityPill(me ?? _placeholder)),
          ] else ...[
            Text(context.k(AccountIdentityKeys.title), style: DText.h2),
            const Gap(6),
            Text(context.k(v.isRejected ? AccountIdentityKeys.introRejected : AccountIdentityKeys.introAgain), style: DText.muted),
            const Gap(14),
            IdentityReasons(v),
            const Gap(14),
            DSeg<String>(
              options: [('egyptian_id', context.k(AccountIdentityKeys.egyptianId)), ('passport', context.k(AccountIdentityKeys.passport))],
              value: _doc!,
              onChanged: (d) => setState(() {
                _doc = d;
                _error = null;
              }),
            ),
            const Gap(14),
            if (_passport) ...[
              _slot(context.k(AccountIdentityKeys.passportPage), _front, true),
              const Gap(10),
              _slot(context.k(AccountIdentityKeys.passportBack), _back, false),
            ] else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _slot(context.k(AccountIdentityKeys.front), _front, true)),
                    const SizedBox(width: 10),
                    Expanded(child: _slot(context.k(AccountIdentityKeys.back), _back, false)),
                  ],
                ),
              ),
            const Gap(10),
            Text(context.k(AccountIdentityKeys.photoTip), style: DText.tiny),
            const Gap(16),
            DError(_error ?? '', visible: _error != null),
            const Gap(12),
            DButton(context.k(AccountIdentityKeys.send), loading: _busy, onTap: _send),
          ],
        ],
      ),
    );
  }

  /// Only for a signed-out visit, which the router does not normally allow.
  static const _placeholder = CustomerProfile(
    id: '',
    displayRef: '',
    phone: '',
    email: null,
    emailVerifiedAt: null,
    fullName: null,
    preferredLang: 'en',
    governorate: null,
    status: 'pending_verification',
    isVerified: false,
    isSuspended: false,
    suspendedReason: null,
    tradeAllowed: false,
    createdAt: null,
  );
}
