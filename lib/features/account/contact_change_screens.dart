import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/idempotency.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/repositories.dart';
import '../../widgets/widgets.dart';
import 'account_messages.dart';

/// `#/change-phone` — move the account to a new number (backend spec 017 FR-001, FR-002):
/// a code goes to the new number, the old one is told, withdrawals pause.
class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _challengeId;
  String _sentTo = '';
  String? _error;
  bool _busy = false;
  String? _sendKey;
  String? _confirmKey;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// `01012345678` or `+201012345678` → E.164.
  static String? _e164(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(digits)) return digits;
    if (RegExp(r'^01\d{9}$').hasMatch(digits)) return '+2$digits';
    return null;
  }

  Future<void> _send() async {
    final phone = _e164(_phone.text);
    if (phone == null) return setState(() => _error = 'Enter a mobile number, like 010 1234 5678.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _sendKey ??= newIdempotencyKey();
      final c = await context.read<AccountRepository>().requestPhoneChange(phone, idempotencyKey: _sendKey!);
      if (!mounted) return;
      setState(() {
        _challengeId = c.id;
        _sentTo = c.phoneMasked;
        _sendKey = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = accountErrorMessage(e));
      if (e.code != 'network_error') _sendKey = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(code)) return setState(() => _error = 'Enter the code from the message.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _confirmKey ??= newIdempotencyKey();
      final pauseUntil = await context.read<AccountRepository>().confirmPhoneChange(_challengeId!, code, idempotencyKey: _confirmKey!);
      if (!mounted) return;
      await context.read<AuthController>().refreshMe();
      if (!mounted) return;
      await tell(
        context,
        title: 'Your number is changed',
        body: pauseUntil == null
            ? 'We told your old number. Your other devices were signed out.'
            : '${context.tr('We told your old number. Your other devices were signed out.')} ${context.tr('Withdrawals are paused until')} ${whenOf(pauseUntil)}.',
      );
      if (mounted) context.back();
    } on ApiException catch (e) {
      _confirmKey = null;
      if (mounted) setState(() => _error = accountErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _challengeId != null;
    return AppPage(
      id: R.changePhone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('We send a code to the new number and tell the old one. Withdrawals pause for 48 hours after the change.', style: DText.muted),
          const Gap(16),
          if (!waiting) ...[
            DField(
              label: 'New phone number',
              bottom: 0,
              child: DInput(controller: _phone, hint: '010 1234 5678', keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
            ),
            DError(_error ?? '', visible: _error != null),
            const Gap(14),
            DButton('Send the code', loading: _busy, onTap: _send),
          ] else ...[
            T('${context.t('We sent a code to')} $_sentTo', style: DText.body14),
            const Gap(12),
            DField(
              label: 'Code',
              bottom: 0,
              child: DInput(controller: _code, hint: '••••••', keyboardType: TextInputType.number, textDirection: TextDirection.ltr),
            ),
            DError(_error ?? '', visible: _error != null),
            const Gap(14),
            DButton('Change my number', loading: _busy, onTap: _confirm),
            const Gap(9),
            DButton.ghost(
              'Use another number',
              onTap: () => setState(() {
                _challengeId = null;
                _code.clear();
                _error = null;
              }),
            ),
          ],
          const Gap(16),
          const DNote(icon: 'shield-lock', text: 'Dahab will never ask for your password or your code, on any channel. If someone does, it is not us.'),
        ],
      ),
    );
  }
}

/// `#/change-email` — a link goes to the new address (backend spec 017 FR-010).
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _email = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;
  String? _key;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return setState(() => _error = 'Enter an email address.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _key ??= newIdempotencyKey();
      final sent = await context.read<AccountRepository>().requestEmailChange(email, idempotencyKey: _key!);
      if (mounted) setState(() => _sentTo = sent);
      _key = null;
    } on ApiException catch (e) {
      if (e.code != 'network_error') _key = null;
      if (mounted) setState(() => _error = accountErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentTo;
    return AppPage(
      id: R.changeEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('We send a link to the new address and tell the old one. Your email is one of the two checks on withdrawals.', style: DText.muted),
          const Gap(16),
          if (sent == null) ...[
            DField(
              label: 'New email address',
              bottom: 0,
              child: DInput(controller: _email, hint: 'name@example.com', keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr),
            ),
            DError(_error ?? '', visible: _error != null),
            const Gap(14),
            DButton('Send the link', loading: _busy, onTap: _send),
          ] else ...[
            DNote(icon: 'mail', kind: NoteKind.ok, text: '${context.t('We sent a link to')} $sent. ${context.t('Open it within 30 minutes to finish the change.')}'),
            const Gap(14),
            DButton.ghost('Done', onTap: context.back),
          ],
        ],
      ),
    );
  }
}

/// `#/email-confirm?token=` — the page the email-change link opens (backend
/// spec 017 FR-010). No sign-in: the token is the secret.
class EmailConfirmScreen extends StatefulWidget {
  const EmailConfirmScreen({super.key, required this.token});

  final String token;

  @override
  State<EmailConfirmScreen> createState() => _EmailConfirmScreenState();
}

class _EmailConfirmScreenState extends State<EmailConfirmScreen> {
  String? _email;
  bool _invalid = false;
  bool _failed = false;
  bool _busy = false;
  bool _done = false;
  DateTime? _pauseUntil;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(EmailConfirmScreen old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token) {
      _email = null;
      _done = false;
      _read();
    }
  }

  Future<void> _read() async {
    setState(() {
      _failed = false;
      _invalid = false;
    });
    if (widget.token.length < 20) return setState(() => _invalid = true);
    try {
      final email = await context.read<AccountRepository>().readEmailLink(widget.token);
      if (mounted) setState(() => _email = email);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => e.code == 'change_link_invalid' || e.code == 'validation_failed' ? _invalid = true : _failed = true);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final pause = await context.read<AccountRepository>().confirmEmailLink(widget.token);
      if (mounted) {
        setState(() {
          _done = true;
          _pauseUntil = pause;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'change_link_invalid') {
        setState(() => _invalid = true);
      } else {
        showToast(context, accountErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_invalid) {
      body = DEmpty(
        icon: 'alert-triangle',
        title: 'This link has expired',
        body: 'Ask for a new one from Your details in the app.',
        action: 'Open Dahab',
        onAction: () => context.enterApp(R.home),
      );
    } else if (_failed) {
      body = DErrorState(onRetry: _read);
    } else if (_email == null) {
      body = const DLoading(height: 240);
    } else if (_done) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DNote(icon: 'circle-check', kind: NoteKind.ok, text: '${context.t('Your email is now')} $_email.'),
          if (_pauseUntil != null) ...[const Gap(10), T('${context.t('Withdrawals are paused until')} ${whenOf(_pauseUntil!)}.', style: DText.tiny)],
          const Gap(14),
          DButton('Open Dahab', onTap: () => context.enterApp(R.home)),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Change your email to', style: DText.tiny),
          const Gap(6),
          T(_email!, style: DText.title),
          const Gap(14),
          const DNote(icon: 'shield-lock', text: 'Only confirm if you asked for this change yourself. If you did not, ignore this link and change your password.'),
          const Gap(14),
          DButton('Confirm this email', loading: _busy, onTap: _confirm),
        ],
      );
    }
    return AppPage(id: R.emailConfirm, child: body);
  }
}
