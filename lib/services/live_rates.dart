import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/prices.dart';
import 'api/prices_api.dart';
import 'pricing.dart';

/// Today's gold prices and the seller's quotes from the backend (spec 015,
/// `GET /reference/gold-prices` and `/reference/quote`). Prices are read on
/// start and every minute; a karat whose price moved flashes up or down
/// briefly, as the prototype's rate bar does. Quotes are asked 400 ms after
/// the last change and cached per piece. No pricing happens in the app.
///
/// [paused] is true when the backend has no usable price (`price_unavailable`)
/// or cannot be reached: the screens say prices are paused instead of showing
/// a stale or invented figure.
class LiveRates extends ChangeNotifier {
  LiveRates({PricesApi? api, Duration poll = const Duration(minutes: 1)}) : _api = api {
    if (_api != null) {
      unawaited(refresh());
      _timer = Timer.periodic(poll, (_) => refresh());
    }
  }

  final PricesApi? _api;
  Timer? _timer;
  Timer? _flashTimer;
  Timer? _quoteTimer;
  bool _disposed = false;

  GoldPrices? _prices;
  bool _paused = false;
  final Map<int, int> _flash = {};

  final Map<QuoteParams, SellQuote> _quotes = {};
  QuoteParams? _asked;
  bool _quotePaused = false;

  bool get ready => _prices != null;
  bool get paused => _paused;
  GoldPrices? get prices => _prices;

  /// What a seller gets per gram of [karat], or null before the first read or when that karat is off.
  num? sellersGet(int karat) => _prices?.karats[karat]?.sellersGet;

  /// What a buyer pays per gram of [karat].
  num? buyersPay(int karat) => _prices?.karats[karat]?.buyersPay;

  /// Sellers get per gram, rounded for display; 0 when unknown.
  int rate(int karat) => (sellersGet(karat) ?? 0).round();

  /// +1 just went up, -1 just went down, 0 steady.
  int flash(int karat) => _flash[karat] ?? 0;

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    try {
      final next = await api.goldPrices();
      if (_disposed) return;
      final before = _prices;
      _flash.clear();
      if (before != null) {
        for (final e in next.karats.entries) {
          final old = before.karats[e.key]?.sellersGet;
          if (old != null && old != e.value.sellersGet) _flash[e.key] = e.value.sellersGet > old ? 1 : -1;
        }
      }
      final moved = before != null && _flash.isNotEmpty;
      _prices = next;
      _paused = false;
      if (moved) _quotes.clear();
      notifyListeners();
      if (_flash.isNotEmpty) {
        _flashTimer?.cancel();
        _flashTimer = Timer(const Duration(milliseconds: 900), () {
          if (_disposed) return;
          _flash.clear();
          notifyListeners();
        });
      }
    } catch (_) {
      if (_disposed) return;
      _paused = true;
      notifyListeners();
    }
  }

  /// The backend's estimate for [params]: the cached one, else the last one shown while a new one is asked.
  SellQuote? quote(QuoteParams params) {
    final cached = _quotes[params];
    if (cached != null || !params.askable || _api == null) return cached;
    if (_asked != params) {
      _asked = params;
      _quoteTimer?.cancel();
      _quoteTimer = Timer(const Duration(milliseconds: 400), () => _ask(params));
    }
    return _lastShown;
  }

  /// True when the last quote could not be had (no price, or no connection).
  bool get quotePaused => _quotePaused;

  SellQuote? _lastShown;

  Future<void> _ask(QuoteParams params) async {
    try {
      final q = await _api!.quote(params);
      if (_disposed) return;
      _quotes[params] = q;
      _lastShown = q;
      _quotePaused = false;
    } catch (_) {
      if (_disposed) return;
      _quotePaused = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _flashTimer?.cancel();
    _quoteTimer?.cancel();
    super.dispose();
  }
}
