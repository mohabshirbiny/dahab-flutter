import 'package:flutter/foundation.dart';

import '../models/account.dart';
import 'repositories.dart';

/// Notification preferences — a mutable local copy of the mock data, so edits
/// persist while the app is open. Payout accounts are live in [PayoutController]
/// (backend spec 013).
class AccountController extends ChangeNotifier {
  AccountController(this._repo);

  final AccountRepository _repo;

  List<NotificationPref> prefs = [];

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    prefs = await _repo.notificationPrefs();
    _loaded = true;
    notifyListeners();
  }

  void togglePref(NotificationPref p) {
    if (p.locked) return;
    p.on = !p.on;
    notifyListeners();
  }
}
