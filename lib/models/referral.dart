/// Invite a friend (backend spec 023 Story 4). A commission credit is never wallet money: it only
/// lowers the commission of a later sale.
library;

class ReferralSummary {
  const ReferralSummary({
    required this.enabled,
    required this.code,
    required this.invitesSent,
    required this.joined,
    required this.sold,
    required this.earnedEgp,
    required this.usedEgp,
    required this.availableEgp,
    required this.availableUntil,
    required this.friendPercentOff,
    required this.inviterRewardEgp,
    required this.creditExpiryDays,
    required this.friendSalesCovered,
  });

  /// The programme is open; false while the backend switch is off (the screen is then hidden).
  final bool enabled;
  final String? code;
  final int invitesSent;
  final int joined;
  final int sold;
  final String earnedEgp;
  final String usedEgp;
  final String availableEgp;
  final DateTime? availableUntil;

  // The live terms, for the screen's words (also available as `{referral_*}` placeholders).
  final String friendPercentOff;
  final String inviterRewardEgp;
  final int creditExpiryDays;
  final int friendSalesCovered;

  double get earned => double.tryParse(earnedEgp) ?? 0;
  double get available => double.tryParse(availableEgp) ?? 0;

  factory ReferralSummary.fromJson(Map<String, dynamic> j) {
    final terms = (j['terms'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReferralSummary(
      enabled: j['enabled'] == true,
      code: j['code'] as String?,
      invitesSent: (j['invites_sent'] as num?)?.toInt() ?? 0,
      joined: (j['joined'] as num?)?.toInt() ?? 0,
      sold: (j['sold'] as num?)?.toInt() ?? 0,
      earnedEgp: '${j['earned_egp'] ?? '0'}',
      usedEgp: '${j['used_egp'] ?? '0'}',
      availableEgp: '${j['available_egp'] ?? '0'}',
      availableUntil: j['available_until'] == null ? null : DateTime.tryParse('${j['available_until']}')?.toLocal(),
      friendPercentOff: '${terms['friend_percent_off'] ?? '0'}',
      inviterRewardEgp: '${terms['inviter_reward_egp'] ?? '0'}',
      creditExpiryDays: (terms['credit_expiry_days'] as num?)?.toInt() ?? 0,
      friendSalesCovered: (terms['friend_sales_covered'] as num?)?.toInt() ?? 1,
    );
  }
}
