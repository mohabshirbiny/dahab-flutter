import 'package:flutter/foundation.dart';

import 'repositories.dart';

/// The bell's unread count (backend spec 017 FR-032). Refreshed when the app
/// shell appears and after the inbox marks something read; a failure keeps
/// the last count.
class InboxController extends ChangeNotifier {
  InboxController(this._repo, {this.onCountChanged});

  final AccountRepository _repo;

  /// Called when the unread count moves: a new message may say the ID was approved or sent
  /// back, so the app reloads the customer (backend testing fixes item 4).
  final void Function()? onCountChanged;

  int _unread = 0;
  int get unread => _unread;

  DateTime? _checkedAt;

  /// At most once every 30 seconds unless [force].
  Future<void> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _checkedAt != null && now.difference(_checkedAt!) < const Duration(seconds: 30)) return;
    _checkedAt = now;
    try {
      final n = await _repo.unreadCount();
      if (n != _unread) {
        final grew = n > _unread;
        _unread = n;
        notifyListeners();
        if (grew) onCountChanged?.call();
      }
    } on Object {
      // Keep the last count.
    }
  }

  void set(int unread) {
    if (unread == _unread) return;
    _unread = unread;
    notifyListeners();
  }
}
