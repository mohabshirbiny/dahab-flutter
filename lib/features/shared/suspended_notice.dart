import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth/auth_controller.dart';
import '../../widgets/widgets.dart';

/// Backend spec 007 US4: tells a suspended customer plainly that the account is
/// suspended and why. The reason comes as a code (`suspended_reason` on
/// `/customer/auth/me`); the staff note is never sent to the app. Trading is
/// refused by the backend (`account_suspended`); reading still works.
class SuspendedNotice extends StatelessWidget {
  const SuspendedNotice({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  /// Customer-facing wording per backend reason code (English source strings;
  /// Arabic in `ar_extra.dart`). A code the app does not know yet gets [general].
  static const reasons = {
    'piece_misrepresented': 'A piece you listed was not as described.',
    'off_platform_dealing': 'We found dealing outside the app, which our terms do not allow.',
    'repeated_disputes': 'There have been repeated disputes on your orders.',
    'reported_by_users': 'Other users reported a problem with your account.',
    'identity_unconfirmed': 'We could not confirm your identity.',
    'customer_request': 'You asked us to close your account.',
    // Set by the system (backend spec 012), never by staff.
    'repeated_cancellations': 'Too many of your accepted sales were cancelled.',
    'other': general,
  };

  static const general = 'Contact us to find out more.';

  static const reads = 'You can still see your account, your orders and your wallet, but you cannot buy, sell or withdraw for now.';

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().customer;
    if (me == null || me.status != 'suspended') return const SizedBox.shrink();

    final why = reasons[me.suspendedReason] ?? general;
    return DNote(
      icon: 'alert-triangle',
      kind: NoteKind.wait,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const T(
            'Your account is suspended',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DColors.wait),
          ),
          const SizedBox(height: 3),
          T(why, style: const TextStyle(fontSize: 11, height: 1.6, color: DColors.wait)),
          const T(reads, style: TextStyle(fontSize: 11, height: 1.6, color: DColors.wait)),
        ],
      ),
    );
  }
}
