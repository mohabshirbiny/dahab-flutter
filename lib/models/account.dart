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

/// One open session on the account (backend spec 017, `GET /customer/me/sessions`).
class AccountSession {
  const AccountSession({required this.id, required this.platform, required this.userAgent, required this.lastActiveAt, required this.current, required this.deviceKnown});

  final String id;

  /// `ios` / `android` / `web`, or null for a session from before the backend kept it.
  final String? platform;
  final String? userAgent;
  final DateTime? lastActiveAt;
  final bool current;
  final bool deviceKnown;

  factory AccountSession.fromJson(Map<String, dynamic> j) => AccountSession(
    id: '${j['session_id']}',
    platform: j['platform'] as String?,
    userAgent: j['user_agent'] as String?,
    lastActiveAt: DateTime.tryParse('${j['last_active_at'] ?? ''}'),
    current: j['is_current'] == true,
    deviceKnown: j['device_known'] == true,
  );

  /// "iPhone or iPad", "Chrome on Windows"… from what the backend knows; never invented.
  String get name {
    final ua = userAgent ?? '';
    final browser = ua.contains('Edg/')
        ? 'Edge'
        : ua.contains('Chrome/')
        ? 'Chrome'
        : ua.contains('Firefox/')
        ? 'Firefox'
        : ua.contains('Safari/')
        ? 'Safari'
        : null;
    return switch (platform) {
      'ios' => 'iPhone or iPad',
      'android' => 'Android',
      'web' => browser ?? 'A browser',
      _ => 'A device',
    };
  }
}

/// A phone change waiting for its code (backend spec 017 FR-001).
class PhoneChallenge {
  const PhoneChallenge({required this.id, required this.phoneMasked, required this.expiresAt});
  final String id;
  final String phoneMasked;
  final DateTime? expiresAt;
}

/// One inbox item (backend spec 017 FR-031). The backend sends both texts;
/// [title] and [body] pick the app's language.
class InboxItem {
  const InboxItem({
    required this.id,
    required this.type,
    required this.linkKind,
    required this.linkId,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String type;
  final String linkKind;
  final String? linkId;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;
  String title(bool arabic) => arabic ? titleAr : titleEn;
  String body(bool arabic) => arabic ? bodyAr : bodyEn;

  factory InboxItem.fromJson(Map<String, dynamic> j) {
    final link = ((j['link'] as Map?) ?? const {}).cast<String, dynamic>();
    return InboxItem(
      id: '${j['id']}',
      type: '${j['type'] ?? ''}',
      linkKind: '${link['kind'] ?? 'none'}',
      linkId: link['id'] as String?,
      titleEn: '${j['title_en'] ?? j['title'] ?? ''}',
      titleAr: '${j['title_ar'] ?? j['title'] ?? ''}',
      bodyEn: '${j['body_en'] ?? j['body'] ?? ''}',
      bodyAr: '${j['body_ar'] ?? j['body'] ?? ''}',
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
      readAt: DateTime.tryParse('${j['read_at'] ?? ''}'),
    );
  }
}

class InboxPage {
  const InboxPage({required this.items, required this.nextCursor, required this.unread});
  final List<InboxItem> items;
  final String? nextCursor;
  final int unread;
}

/// Something that stops the account from closing (backend spec 017 FR-050).
class CloseBlocker {
  const CloseBlocker(this.code, this.count);
  final String code;
  final int count;

  /// What it means, in the app's words.
  String get label => switch (code) {
    'open_order' => 'An order still in progress',
    'active_buy_request' => 'A buy request still waiting',
    'listing_in_sale' => 'A piece of yours with a buyer',
    'piece_at_branch' => 'A piece waiting for you at a branch',
    'wallet_balance' => 'Money in your wallet',
    'pending_withdrawal' => 'A withdrawal that has not left yet',
    'open_dispute' => 'A problem report still open',
    'pending_extension_request' => 'A request for more time still waiting',
    'pending_topup' => 'A transfer we have not added yet',
    _ => 'Something still in progress',
  };
}

/// A legal document the app lists (backend spec 017 FR-045).
class LegalEntry {
  const LegalEntry({required this.code, required this.published});
  final String code;
  final bool published;

  String get title => switch (code) {
    'terms' => 'Terms of use',
    'privacy' => 'Privacy policy',
    'selling_rules' => 'Selling rules and deadlines',
    'id_handling' => 'How we handle your ID and documents',
    _ => code,
  };
}

/// How to reach Dahab (`/reference/support-contacts`).
class SupportContacts {
  const SupportContacts({required this.phone, required this.hoursEn, required this.hoursAr, required this.whatsapp, required this.email, required this.social});
  final String phone;
  final String hoursEn;
  final String hoursAr;
  final String whatsapp;
  final String email;
  final Map<String, String> social;

  factory SupportContacts.fromJson(Map<String, dynamic> j) => SupportContacts(
    phone: '${j['phone'] ?? ''}',
    hoursEn: '${j['hours_en'] ?? ''}',
    hoursAr: '${j['hours_ar'] ?? ''}',
    whatsapp: '${j['whatsapp'] ?? ''}',
    email: '${j['email'] ?? ''}',
    social: ((j['social'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
  );
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
