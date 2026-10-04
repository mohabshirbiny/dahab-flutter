import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'pricing.dart';

/// Mock live gold feed. Every 6 seconds each karat drifts up to ±7 EGP
/// around its base rate, and briefly flags whether it went up or down —
/// exactly what the prototype's rate bar does.
class LiveRates extends ChangeNotifier {
  LiveRates({Duration tick = const Duration(seconds: 6)}) {
    _timer = Timer.periodic(tick, (_) => _tick());
  }

  final _rng = math.Random();
  late final Timer _timer;
  Timer? _flashTimer;

  final Map<int, int> _rates = Map.of(Pricing.baseRates);
  final Map<int, int> _flash = {};

  /// Current buy rate per gram (what a seller gets), by karat.
  int rate(int karat) => _rates[karat] ?? Pricing.baseRates[karat]!;

  /// +1 just went up, -1 just went down, 0 steady.
  int flash(int karat) => _flash[karat] ?? 0;

  void _tick() {
    for (final k in Pricing.baseRates.keys) {
      final base = Pricing.baseRates[k]!;
      final v = base + ((_rng.nextDouble() - 0.5) * 14).round();
      _flash[k] = v > base ? 1 : -1;
      _rates[k] = v;
    }
    notifyListeners();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      _flash.clear();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }
}
