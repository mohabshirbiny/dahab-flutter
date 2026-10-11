import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/auth_reset.dart';
import '../../core/text/texts_controller.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../widgets/widgets.dart';

/// Forgot password, step 2 (backend spec 020): the six digit code and the new password. A
/// reset ends every session and device, so the customer goes back to sign in afterwards.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  String _code = '';
  final _password = TextEditingController();
  final _confirm = TextEditingController();
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
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.length < 6) return setState(() => _error = context.kr(AuthResetKeys.codeMissing));
    if (_password.text.length < 10) return setState(() => _error = context.kr(AuthResetKeys.passwordShort));
    if (_password.text != _confirm.text) return setState(() => _error = context.kr(AuthResetKeys.passwordMismatch));
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthController>().confirmPasswordReset(code: _code, password: _password.text);
      if (mounted) context.enterApp(R.login);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthController>();
    final phone = auth.resetPhone;
    if (phone == null) return;
    try {
      await auth.requestPasswordReset(phone);
      if (mounted) showToast(context, context.kr(AuthResetKeys.sentAgain));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final phone = auth.resetPhone;
    if (phone == null) {
      // Opened directly, or the reset already finished: start from the phone.
      return AppPage(
        id: R.resetPassword,
        child: DEmpty(
          icon: 'shield-lock',
          title: context.k(AuthResetKeys.askTitle),
          body: context.k(AuthResetKeys.askBody),
          action: context.k(AuthResetKeys.startOver),
          onAction: () => context.nav(R.forgotPassword),
        ),
      );
    }
    final wait = (auth.resetResendAvailableAt ?? DateTime.now()).difference(DateTime.now()).inSeconds;
    return AppPage(
      id: R.resetPassword,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.k(AuthResetKeys.setTitle), style: DText.h2),
            const Gap(6),
            Text(context.k(AuthResetKeys.setBody, {'phone': maskPhone(phone)}), style: DText.muted),
            const Gap(20),
            DField(label: context.k(AuthResetKeys.codeLabel), child: DOtp(onChanged: (v) => setState(() => _code = v))),
            const Gap(6),
            Center(
              child: wait > 0
                  ? Text(context.k(AuthResetKeys.resendIn, {'seconds': wait}), style: DText.tiny)
                  : Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(context.k(AuthResetKeys.didntArrive), style: DText.tiny),
                        const SizedBox(width: 4),
                        DLink(context.k(AuthResetKeys.sendAgain), onTap: _resend),
                      ],
                    ),
            ),
            const Gap(16),
            DField(
              label: context.k(AuthResetKeys.newPasswordLabel),
              child: DInput(controller: _password, password: true, hint: context.k(AuthResetKeys.passwordHint), autofillHints: const [AutofillHints.newPassword]),
            ),
            DField(
              label: context.k(AuthResetKeys.confirmPasswordLabel),
              child: DInput(controller: _confirm, password: true, onSubmitted: (_) => _submit(), autofillHints: const [AutofillHints.newPassword]),
            ),
            const Gap(18),
            DButton(context.k(AuthResetKeys.submit), loading: _busy, onTap: _submit),
            DError(_error ?? '', visible: _error != null),
            const Gap(20),
            Center(child: DLink(context.k(AuthResetKeys.startOver), onTap: () => context.nav(R.forgotPassword))),
          ],
        ),
      ),
    );
  }
}
