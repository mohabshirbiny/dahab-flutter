import 'dart:math' as math;

/// Pricing rules, ported 1:1 from the prototype's `homeCalc` / `sellCalc`.
/// Pure functions — no UI, no state — so they can be unit tested and later
/// replaced by server-side quotes.
abstract final class Pricing {
  /// `RATE` — Dahab's buy rate per gram (what a seller gets), by karat.
  static const baseRates = {18: 5958, 21: 6951, 24: 7944};

  /// A buyer pays this much more per gram than a seller gets (splash cards).
  static const buySpread = 24;

  /// `COMM` — commission share by type.
  static const commGold = 0.20;
  static const commStone = 0.05;

  /// `MIN` — minimum commission in EGP.
  static const minCommission = 200;

  /// `JEW_STONE` — what a jeweller pays for a stone, as a share of its value.
  static const jewellerStoneShare = 0.50;

  /// `BASE_CT` — Rapaport-style base value of a 1ct VS / very good stone.
  static const baseCaratValue = 55000;

  /// Commission on [base] at [pct], never below the minimum, never above the base itself.
  static double commission(double base, double pct) {
    if (base <= 0) return 0;
    var c = math.max(base * pct, minCommission.toDouble());
    if (c > base) c = base;
    return c;
  }

  /// Home calculator: what a gold seller receives.
  static GoldQuote gold({required int rate, required double weight, required double makingPerGram}) {
    final gold = rate * weight;
    final making = makingPerGram * weight;
    final comm = commission(making, commGold);
    return GoldQuote(rate: rate, goldValue: gold, making: making, commission: comm);
  }

  /// `sug` — suggested stone price from carat, clarity and cut factors.
  static double suggestedStone(double carat, double clarity, double cut) => baseCaratValue * math.pow(carat, 1.4) * clarity * cut;

  /// Sell flow summary for all three piece types.
  static SellQuote sell({
    required SellType type,
    required int rate,
    required double weight,
    required double makingPerGram,
    required double stoneAsk,
    required double totalAsk,
  }) {
    final isGold = type == SellType.gold;
    final gold = type == SellType.diamond ? 0.0 : rate * weight;
    final making = isGold ? makingPerGram * weight : 0.0;
    final stone = type == SellType.diamond ? stoneAsk : 0.0;
    final ask = type == SellType.mixed ? totalAsk : 0.0;

    final double base, gross, jeweller;
    switch (type) {
      case SellType.gold:
        base = making;
        gross = gold + making;
        jeweller = gold;
      case SellType.diamond:
        base = stone;
        gross = stone;
        jeweller = stone * jewellerStoneShare;
      case SellType.mixed:
        base = ask;
        gross = ask;
        jeweller = gold + math.max(ask - gold, 0) * jewellerStoneShare;
    }
    final pct = isGold ? commGold : commStone;
    final comm = commission(base, pct);
    final atMinimum = base > 0 && base * pct < minCommission;
    return SellQuote(
      goldValue: gold,
      making: making,
      stone: stone,
      ask: ask,
      commission: comm,
      net: gross - comm,
      jewellerPays: jeweller,
      commissionNote: atMinimum ? '(minimum $minCommission EGP)' : '(${(pct * 100).round()}% of ${isGold ? 'the making charge' : 'the full price'})',
    );
  }
}

enum SellType { gold, diamond, mixed }

class GoldQuote {
  const GoldQuote({required this.rate, required this.goldValue, required this.making, required this.commission});

  final int rate;
  final double goldValue;
  final double making;
  final double commission;

  double get net => goldValue + making - commission;

  /// "A jeweller pays gold only".
  double get jewellerPays => goldValue;
  double get extra => net - goldValue;
}

class SellQuote {
  const SellQuote({
    required this.goldValue,
    required this.making,
    required this.stone,
    required this.ask,
    required this.commission,
    required this.net,
    required this.jewellerPays,
    required this.commissionNote,
    this.certificateFee = 0,
    this.rate = 0,
  });

  /// Gold: what the seller gets per gram of this karat now (0 when not known).
  final double rate;

  final double goldValue;
  final double making;
  final double stone;
  final double ask;
  final double commission;
  final double net;
  final double jewellerPays;
  final String commissionNote;

  /// The stone certificate cost already out of [net] (0 for gold or none).
  final double certificateFee;
}
