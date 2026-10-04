import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../mock/mock_account.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../widgets/widgets.dart';

/// `#s-login` — phone + password against `POST /customer/auth/login`.
/// A trusted device goes straight in; a new device continues to the SMS code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _cc = '+20';
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty) return setState(() => _error = 'Enter your phone number.');
    if (_pw.text.isEmpty) return setState(() => _error = 'Enter your password.');
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final outcome = await context.read<AuthController>().login(phone: toE164(_cc, _phone.text), password: _pw.text);
      if (!mounted) return;
      if (outcome == LoginOutcome.signedIn) {
        context.enterApp(R.home);
      } else {
        context.nav(R.otp);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.login,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const T('Welcome back', style: DText.h2),
            const Gap(6),
            const T('Sign in with the phone number on your account.', style: DText.muted),
            const Gap(20),
            DField(
              label: 'Phone number',
              child: PhoneInput(code: _cc, onCode: (v) => setState(() => _cc = v), controller: _phone, hint: '10 1234 4417'),
            ),
            DField(
              label: 'Password',
              child: DInput(controller: _pw, password: true, onSubmitted: (_) => _submit()),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DLink('Forgot your password?', onTap: () => showToast(context, 'Password reset is not available yet.')),
            ),
            const Gap(18),
            DButton('Sign in', loading: _busy, onTap: _submit),
            DError(_error ?? '', visible: _error != null),
            const Gap(16),
            const DNote(icon: 'shield-lock', text: 'We send a code to your phone every time you sign in from a new device.'),
            const Gap(20),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  T('New here?', style: DText.muted.copyWith(height: 1.2)),
                  const SizedBox(width: 4),
                  DLink('Create an account', style: DText.link13, onTap: () => context.nav(R.signup1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Country code picker + phone number input.
class PhoneInput extends StatelessWidget {
  const PhoneInput({super.key, required this.code, required this.onCode, required this.controller, this.hint});

  final String code;
  final ValueChanged<String> onCode;
  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: DSelect<String>(options: mockCountryCodes, value: code, onChanged: onCode, translateLabels: false),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DInput(controller: controller, hint: hint, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
        ),
      ],
    );
  }
}

/// `#s-otp` — the SMS code for a sign-in from a new device
/// (`POST /customer/auth/otp/verify`, resend via `/otp/resend`).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _code = '';
  String? _error;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Re-render once a second so the resend countdown moves.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length < 6) return setState(() => _error = 'Enter the code we sent you.');
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthController>().verifyLoginOtp(_code);
      if (mounted) context.enterApp(R.home);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await context.read<AuthController>().resendLoginOtp();
      if (mounted) showToast(context, 'Code sent again.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final challenge = auth.pendingChallenge;
    if (challenge == null) {
      // Opened directly, or the challenge is already used: start from sign-in.
      return AppPage(
        id: R.otp,
        child: DEmpty(icon: 'shield-lock', title: 'Enter your code', body: 'Sign in again.', action: 'Sign in', onAction: () => context.enterApp(R.login)),
      );
    }
    final wait = challenge.resendAvailableAt.difference(DateTime.now()).inSeconds;
    return AppPage(
      id: R.otp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T('Enter your code', style: DText.h2),
          const Gap(6),
          Text('${context.t('We sent a six digit code to')} ${maskPhone(auth.pendingPhone ?? '')}.', style: DText.muted),
          const Gap(20),
          DOtp(onChanged: (v) => setState(() => _code = v)),
          const Gap(14),
          Center(
            child: wait > 0
                ? Text('${context.t('You can ask for a new code in')} ${wait}s', style: DText.tiny)
                : Wrap(
                    children: [
                      const T("Didn't arrive?", style: DText.tiny),
                      const SizedBox(width: 4),
                      DLink('Send it again', onTap: _resend),
                    ],
                  ),
          ),
          const Gap(20),
          DButton('Verify', loading: _busy, onTap: _verify),
          DError(_error ?? '', visible: _error != null),
        ],
      ),
    );
  }
}
