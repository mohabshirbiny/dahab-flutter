import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/text/keys/auth_reset.dart';
import '../../core/text/texts_controller.dart';
import '../../services/api/api_client.dart';
import '../../services/auth/auth_controller.dart';
import '../../services/auth/auth_messages.dart';
import '../../widgets/widgets.dart';
import 'login_screens.dart';

/// Forgot password, step 1 (backend spec 020): the phone on the account. The answer never says
/// whether the number is registered, so this screen always moves on to the code.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String _cc = '+20';
  final _phone = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty) return setState(() => _error = context.kr(AuthResetKeys.phoneMissing));
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthController>().requestPasswordReset(toE164(_cc, _phone.text));
      if (mounted) context.nav(R.resetPassword);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      id: R.forgotPassword,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.k(AuthResetKeys.askTitle), style: DText.h2),
          const Gap(6),
          Text(context.k(AuthResetKeys.askBody), style: DText.muted),
          const Gap(20),
          DField(
            label: 'Phone number',
            child: PhoneInput(code: _cc, onCode: (v) => setState(() => _cc = v), controller: _phone, hint: '10 1234 4417'),
          ),
          const Gap(18),
          DButton(context.k(AuthResetKeys.sendCode), loading: _busy, onTap: _submit),
          DError(_error ?? '', visible: _error != null),
          const Gap(20),
          Center(child: DLink(context.k(AuthResetKeys.backToSignIn), onTap: () => context.nav(R.login))),
        ],
      ),
    );
  }
}
