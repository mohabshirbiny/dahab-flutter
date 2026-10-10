import 'package:flutter/foundation.dart';

import '../models/buy_request.dart';

/// Local UI session state — what the prototype kept in globals
/// (`isGuest`, `emailOK`, …).
/// Nothing here talks to a server.
class AppSession extends ChangeNotifier {
  AppSession();

  // ---- auth (mock) ----
  bool _guest = false;
  bool get isGuest => _guest;

  /// "Look around first".
  void enterAsGuest() {
    _guest = true;
    notifyListeners();
  }

  /// OTP verified / account created.
  void signIn() {
    _guest = false;
    notifyListeners();
  }

  void signOut() {
    _guest = false;
    notifyListeners();
  }

  // ---- home calculator (kept across tab switches, like the DOM was) ----
  int homeKarat = 21;
  double homeWeight = 8;
  double homeMaking = 300;

  void setHome({int? karat, double? weight, double? making}) {
    homeKarat = karat ?? homeKarat;
    homeWeight = weight ?? homeWeight;
    homeMaking = making ?? homeMaking;
    notifyListeners();
  }

  // ---- piece detail ----

  // ---- buy request (backend spec 011) ----
  /// The request just sent, for *Request sent*.
  BuyRequest? lastRequest;

  /// What the deposit needs when the wallet was short, for *You need a little more*.
  DepositShortfall? shortfall;

  void requestSent(BuyRequest request) {
    lastRequest = request;
    shortfall = null;
    notifyListeners();
  }

  void walletShort(DepositShortfall value) {
    shortfall = value;
    notifyListeners();
  }

  // ---- admin toggle on the review screen ----
  bool _payStatsVisible = false;
  bool get payStatsVisible => _payStatsVisible;

  void togglePayStats() {
    _payStatsVisible = !_payStatsVisible;
    notifyListeners();
  }
}
