import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/tokens.dart';
import 'buttons.dart';

OverlayEntry? _toastEntry;
Timer? _toastTimer;
final _toastVisible = ValueNotifier<bool>(false);

/// `saved(msg)` — the dark pill toast above the tab bar, shown for 1.9s.
void showToast(BuildContext context, String message) {
  final text = context.tr(message);
  final overlay = Overlay.of(context);
  _toastTimer?.cancel();
  _toastEntry?.remove();
  _toastEntry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      right: 0,
      bottom: 78,
      child: IgnorePointer(
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: _toastVisible,
            builder: (_, visible, child) => AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 200), child: child),
            child: FractionallySizedBox(
              widthFactor: 0.88,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(color: DColors.ink, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: DColors.white, fontSize: 12, decoration: TextDecoration.none),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(_toastEntry!);
  _toastVisible.value = false;
  WidgetsBinding.instance.addPostFrameCallback((_) => _toastVisible.value = true);
  _toastTimer = Timer(const Duration(milliseconds: 1900), () {
    _toastVisible.value = false;
    _toastTimer = Timer(const Duration(milliseconds: 220), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  });
}

/// `ask(title, body, yes, cb)` — confirm dialog. Resolves true on confirm.
Future<bool> ask(BuildContext context, {required String title, required String body, String yes = 'Confirm'}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: DColors.modalBarrier,
    builder: (_) => _DModal(title: title, body: body, yes: yes, showCancel: true),
  );
  return ok ?? false;
}

/// `tell(title, body)` — single "OK" dialog.
Future<void> tell(BuildContext context, {required String title, required String body}) {
  return showDialog<void>(
    context: context,
    barrierColor: DColors.modalBarrier,
    builder: (_) => _DModal(title: title, body: body, yes: 'OK', showCancel: false),
  );
}

class _DModal extends StatelessWidget {
  const _DModal({required this.title, required this.body, required this.yes, required this.showCancel});

  final String title;
  final String body;
  final String yes;
  final bool showCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DRadius.modal)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t(title), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(context.t(body), style: const TextStyle(fontSize: 13, color: DColors.ink2, height: 1.65)),
              const SizedBox(height: 16),
              DActsRow(
                gap: 9,
                children: [
                  if (showCancel) DButton.ghost('Cancel', onTap: () => Navigator.of(context).pop(false)),
                  DButton(yes, onTap: () => Navigator.of(context).pop(true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
