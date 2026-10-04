import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../routing/routes.dart';

/// Red markers on everything that still runs on mock data, so nobody mistakes it
/// for the real thing. On by default; a production build turns them off with
/// `--dart-define=SHOW_MOCK_FLAGS=false`. When a screen goes live, take its id out
/// of [mockScreens]; when a part goes live, remove its [MockMark].
const bool kShowMockFlags = bool.fromEnvironment('SHOW_MOCK_FLAGS', defaultValue: true);

/// Screens that are entirely mock (no backend behind them yet).
const Set<String> mockScreens = {
  R.security, // password change and devices
  R.notif, // notification settings
  R.inbox, // notifications feed
  R.help, // FAQ
  R.legal,
  R.support,
  R.delete, // close account
  R.invite,
  R.held, // held-money detail
  R.invoices,
  R.invoice,
  R.saved, // saved pieces
  R.report, // report a listing
  R.branch, // prototype branch picker (the live one is in Accept)
  R.rate, // rate a sale
  R.editprice,
  R.codes,
  R.codeuses,
  R.mmapprove,
  R.compensate,
};

/// The small red "MOCK" flag.
class MockFlag extends StatelessWidget {
  const MockFlag({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kShowMockFlags) return const SizedBox.shrink();
    return Semantics(
      label: 'Mock data',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(color: DColors.bad, borderRadius: BorderRadius.circular(4)),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag, size: 10, color: Colors.white),
              SizedBox(width: 3),
              Text(
                'MOCK',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: .4, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puts a [MockFlag] on the top corner of a part of a live screen that is still mock.
class MockMark extends StatelessWidget {
  const MockMark({super.key, required this.child, this.top = -6, this.bottom, this.end = -4, this.enabled = true});

  final Widget child;

  /// Where the flag sits; by default over the top-end corner.
  final double? top;
  final double? bottom;
  final double end;

  /// False when the part is live in this case (e.g. signed in).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!kShowMockFlags || !enabled) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(top: bottom == null ? top : null, bottom: bottom, end: end, child: const IgnorePointer(child: MockFlag())),
      ],
    );
  }
}

/// The strip at the top of a screen that is entirely mock.
class MockScreenBanner extends StatelessWidget {
  const MockScreenBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kShowMockFlags) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: DColors.bad,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Icon(Icons.flag, size: 13, color: Colors.white),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'MOCK — this screen is not connected to the backend yet',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
