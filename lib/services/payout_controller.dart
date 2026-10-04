import 'package:flutter/foundation.dart';

import '../core/utils/idempotency.dart';
import '../models/payout.dart';
import 'repositories.dart';

/// The customer's payout accounts (backend spec 013), shared by Bank accounts,
/// Your details and Withdraw. Every screen reloads on open; the last answer
/// stays on screen meanwhile. Changes answer with the whole list.
class PayoutController extends ChangeNotifier {
  PayoutController(this._repo);

  final PayoutRepository _repo;

  PayoutView? view;
  Object? error;
  bool loading = false;

  /// One key per action and account: a retry of the same change reuses it, so
  /// the backend replays the first answer instead of acting twice.
  final _keys = <String, String>{};

  PayoutRepository get repo => _repo;

  /// Safe to call from `initState`: listeners hear only the answer.
  Future<void> load() async {
    loading = true;
    error = null;
    try {
      view = await _repo.accounts();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<T> _change<T>(String what, Future<T> Function(String key) run) async {
    final key = _keys.putIfAbsent(what, newIdempotencyKey);
    final result = await run(key);
    _keys.remove(what);
    return result;
  }

  Future<void> add({required String bankName, required String accountName, required String number, required int declarationId}) async {
    final payload = 'add|$bankName|$accountName|$number|$declarationId';
    view = await _change(payload, (key) => _repo.add(bankName: bankName, accountName: accountName, number: number, declarationId: declarationId, idempotencyKey: key));
    notifyListeners();
  }

  /// Returns the numbers of the withdrawals that were cancelled.
  Future<List<String>> use(PayoutAccount a) async {
    final (next, cancelled) = await _change('use|${a.id}', (key) => _repo.use(a.id, idempotencyKey: key));
    view = next;
    notifyListeners();
    return cancelled;
  }

  Future<void> remove(PayoutAccount a) async {
    view = await _change('remove|${a.id}', (key) => _repo.remove(a.id, idempotencyKey: key));
    notifyListeners();
  }

  Future<void> keep(PayoutAccount a) async {
    view = await _change('keep|${a.id}', (key) => _repo.keep(a.id, idempotencyKey: key));
    notifyListeners();
  }
}
