import 'package:flutter/foundation.dart';

import '../core/utils/idempotency.dart';
import 'repositories.dart';

/// The customer's saved pieces (backend spec 017 FR-040): which listings are saved and how many,
/// for the header icon, the Save buttons and *You need a little more*. A failed read keeps the
/// last answer.
class SavedController extends ChangeNotifier {
  SavedController(this._repo);

  final AccountRepository _repo;

  final Set<String> _ids = {};
  int get count => _ids.length;
  bool isSaved(String listingId) => _ids.contains(listingId);

  /// Reads the list from the backend. Signed out, the repository answers with nothing.
  Future<void> refresh() async {
    try {
      final rows = await _repo.saved();
      final ids = {for (final r in rows) r.listingId};
      if (!setEquals(ids, _ids)) {
        _ids
          ..clear()
          ..addAll(ids);
        notifyListeners();
      }
    } on Object {
      // Keep the last answer.
    }
  }

  /// Saves [listingId]; the error of a refused save (limit reached, not on the market) is thrown.
  Future<void> save(String listingId) async {
    await _repo.save(listingId, idempotencyKey: newIdempotencyKey());
    if (_ids.add(listingId)) notifyListeners();
  }

  Future<void> unsave(String listingId) async {
    await _repo.unsave(listingId);
    if (_ids.remove(listingId)) notifyListeners();
  }

  /// Signed out: nothing is shown.
  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
