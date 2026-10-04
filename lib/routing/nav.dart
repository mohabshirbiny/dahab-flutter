import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/auth/auth_controller.dart';
import 'routes.dart';

/// Navigation with the prototype's stack rules (`go(s)` in the HTML):
/// tab roots reset the back stack, every other screen is pushed on top.
extension DahabNav on BuildContext {
  void nav(String id, {Map<String, String>? query}) {
    final loc = Uri(path: '/$id', queryParameters: query).toString();
    if (R.roots.contains(id)) {
      go(loc);
    } else {
      push(loc);
    }
  }

  /// `enterApp(s)` — replace the whole stack.
  void enterApp(String id) => go('/$id');

  /// `goBack()`.
  void back() {
    if (canPop()) {
      pop();
    } else {
      go('/${R.home}');
    }
  }

  /// `trySell()` — anyone not signed in is sent to the account gate first.
  void trySell() => read<AuthController>().isSignedIn ? nav(R.sell1) : nav(R.gate);

  /// Open the piece detail in one of its states.
  void openPiece({String view = 'buyer', String id = 'p1'}) => nav(R.detail, query: {'view': view, 'id': id});
}
