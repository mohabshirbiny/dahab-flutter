class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.fullName,
    required this.sellerId,
    required this.memberSince,
    required this.phoneMasked,
    required this.email,
    required this.payoutShort,
    required this.inviteCode,
  });

  final String displayName;
  final String fullName;
  final String sellerId;
  final String memberSince;
  final String phoneMasked;
  final String email;
  final String payoutShort;
  final String inviteCode;

  String get initial => displayName.isEmpty ? '' : displayName[0];
}

class DeviceSession {
  const DeviceSession({required this.name, required this.sub, required this.current});
  final String name;
  final String sub;
  final bool current;
}

class AppNotification {
  const AppNotification({required this.icon, required this.tone, required this.title, required this.sub, required this.target});

  final String icon;

  /// ok / bad / wait / neutral
  final String tone;
  final String title;
  final String sub;

  /// Screen id to open.
  final String target;
}

class NotificationPref {
  NotificationPref({required this.title, required this.on, this.sub, this.locked = false});
  final String title;
  final String? sub;
  bool on;

  /// Always on (money depends on it).
  final bool locked;
}

class FaqItem {
  const FaqItem(this.question, this.answer);
  final String question;
  final String answer;
}

class Branch {
  const Branch({required this.name, required this.address, required this.status, required this.open, required this.hours, required this.closed, required this.duration});

  final String name;
  final String address;
  final String status;
  final bool open;
  final String hours;
  final String closed;
  final String duration;
}

class PromoCode {
  const PromoCode({required this.code, required this.off, required this.label, this.firstSaleOnly = false});

  final String code;

  /// Fraction of the commission waived (0.5 = 50% off).
  final double off;
  final String label;
  final bool firstSaleOnly;
}
