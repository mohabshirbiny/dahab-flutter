import 'package:flutter/widgets.dart';

import '../../widgets/widgets.dart';

/// `addPhoto(el)` — tapping an empty upload slot marks it added (no real
/// upload happens); tapping a filled one asks before clearing it.
Future<void> togglePhotoSlot(BuildContext context, {required bool done, required VoidCallback toggle}) async {
  if (done) {
    final ok = await ask(context, title: 'Replace this', body: 'You can take it again if you are not happy with it.', yes: 'Replace');
    if (!ok || !context.mounted) return;
    toggle();
    showToast(context, 'Removed. Add a new one.');
  } else {
    toggle();
    showToast(context, 'Added.');
  }
}

/// An upload slot that manages its own added/empty state.
class ToggleSlot extends StatefulWidget {
  const ToggleSlot({super.key, required this.title, this.sub, this.icon = 'camera', this.boxHeight = 56, this.iconSize = 22});

  final String title;
  final String? sub;
  final String icon;
  final double boxHeight;
  final double iconSize;

  @override
  State<ToggleSlot> createState() => _ToggleSlotState();
}

class _ToggleSlotState extends State<ToggleSlot> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return DSlot(
      title: widget.title,
      sub: _done ? 'Added' : widget.sub,
      subColor: _done ? DColors.ok : null,
      icon: widget.icon,
      boxHeight: widget.boxHeight,
      iconSize: widget.iconSize,
      done: _done,
      onTap: () => togglePhotoSlot(context, done: _done, toggle: () => setState(() => _done = !_done)),
    );
  }
}
