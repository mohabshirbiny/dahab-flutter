/// Reference data the sell form needs (backend spec 010, `GET /reference/*`):
/// what a seller may choose, and the text they tick when listing a piece.
/// Public: the app reads it without a session.
library;

/// A kind of piece (`Ring`, `Chain`, …) of one category.
class PieceTypeRef {
  const PieceTypeRef({required this.id, required this.category, required this.nameEn, required this.nameAr});

  final int id;

  /// `gold`, `diamond` or `gold_with_diamond`.
  final String category;
  final String nameEn;
  final String nameAr;

  factory PieceTypeRef.fromJson(Map<String, dynamic> j) =>
      PieceTypeRef(id: (j['id'] as num).toInt(), category: '${j['category']}', nameEn: '${j['name_en'] ?? ''}', nameAr: '${j['name_ar'] ?? ''}');
}

/// One open interval of a branch's week (`dow` 0 = Sunday … 6 = Saturday; times `HH:MM`).
class BranchHourRef {
  const BranchHourRef({required this.dow, required this.opensAt, required this.closesAt});

  final int dow;
  final String opensAt;
  final String closesAt;

  static BranchHourRef? fromJson(Object? raw) {
    if (raw is! Map || raw['dow'] is! num) return null;
    return BranchHourRef(dow: (raw['dow'] as num).toInt(), opensAt: '${raw['opens_at'] ?? ''}', closesAt: '${raw['closes_at'] ?? ''}');
  }
}

/// An inspection branch a seller is willing to bring the piece to, with its hours and how to reach it
/// (`GET /reference/branches`, and the order's `branch`).
class BranchRef {
  const BranchRef({
    required this.id,
    this.labId,
    required this.nameEn,
    required this.nameAr,
    this.addressEn = '',
    this.addressAr = '',
    this.contactPhone,
    this.mapUrl,
    this.hours = const [],
  });

  final int id;
  final int? labId;
  final String nameEn;
  final String nameAr;
  final String addressEn;
  final String addressAr;

  /// Null when staff have not set them.
  final String? contactPhone;
  final String? mapUrl;
  final List<BranchHourRef> hours;

  factory BranchRef.fromJson(Map<String, dynamic> j) => BranchRef(
    labId: (j['lab_id'] as num?)?.toInt(),
    id: (j['id'] as num).toInt(),
    nameEn: '${j['name_en'] ?? ''}',
    nameAr: '${j['name_ar'] ?? ''}',
    addressEn: '${j['address_en'] ?? ''}',
    addressAr: '${j['address_ar'] ?? ''}',
    contactPhone: j['contact_phone'] as String?,
    mapUrl: j['map_url'] as String?,
    hours: [for (final h in (j['hours'] as List? ?? const [])) ?BranchHourRef.fromJson(h)],
  );
}

/// The current version of a legal text (`ownership_declaration`).
class LegalDoc {
  const LegalDoc({required this.id, required this.version, required this.bodyEn, required this.bodyAr});

  final int id;
  final String version;
  final String bodyEn;
  final String bodyAr;

  factory LegalDoc.fromJson(Map<String, dynamic> j) =>
      LegalDoc(id: (j['id'] as num).toInt(), version: '${j['version'] ?? ''}', bodyEn: '${j['body_en'] ?? ''}', bodyAr: '${j['body_ar'] ?? ''}');
}

/// A lab a seller can choose: what it costs them and its open branches (`GET /reference/labs`).
class LabRef {
  const LabRef({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.ownCost,
    required this.otherCost,
    required this.noneCost,
    this.goldCost,
    this.branches = const [],
  });

  final int id;
  final String nameEn;
  final String nameAr;
  final double ownCost;
  final double otherCost;
  final double noneCost;

  /// Null when it is 0: it then appears nowhere.
  final double? goldCost;
  final List<BranchRef> branches;

  String name(bool arabic) => arabic && nameAr.isNotEmpty ? nameAr : nameEn;

  /// The cost at this lab for the form's choice (`lab` with the lab behind it, `other` or `none`).
  double certificateCost(String cert, int? certificateLabId) => switch (cert) {
    'lab' => certificateLabId == id ? ownCost : otherCost,
    'other' => otherCost,
    _ => noneCost,
  };

  factory LabRef.fromJson(Map<String, dynamic> j) {
    final costs = (j['costs'] as Map?)?.cast<String, dynamic>() ?? const {};
    double read(String k) => double.tryParse('${costs[k]}') ?? 0;
    return LabRef(
      id: (j['id'] as num).toInt(),
      nameEn: '${j['name_en'] ?? ''}',
      nameAr: '${j['name_ar'] ?? ''}',
      ownCost: read('own'),
      otherCost: read('other'),
      noneCost: read('none'),
      goldCost: costs['gold'] == null ? null : double.tryParse('${costs['gold']}'),
      branches: [for (final b in (j['branches'] as List? ?? const [])) BranchRef.fromJson((b as Map).cast<String, dynamic>())],
    );
  }
}

/// What IGI's certificate costs the seller, in EGP, by the certificate they bring
/// (`GET /reference/certificate-costs`, set by staff on the Rates page).
class CertificateCosts {
  const CertificateCosts({required this.igi, required this.otherLab, required this.none});

  final double igi;
  final double otherLab;
  final double none;

  /// The cost for the sell form's choice: `igi`, `other` or `none`.
  double of(String cert) => switch (cert) {
    'igi' => igi,
    'other' => otherLab,
    _ => none,
  };

  factory CertificateCosts.fromJson(Map<String, dynamic> j) {
    double read(String k) => double.tryParse('${j[k]}') ?? 0;
    return CertificateCosts(igi: read('igi'), otherLab: read('other_lab'), none: read('none'));
  }
}

/// Everything the sell flow reads before a listing exists.
class SellReference {
  const SellReference({required this.karats, required this.pieceTypes, required this.branches, required this.declaration, this.certificateCosts, this.labs = const []});

  /// Enabled karat codes, in display order.
  final List<int> karats;
  final List<PieceTypeRef> pieceTypes;
  final List<BranchRef> branches;
  final LegalDoc declaration;

  /// Null when the backend could not say (an older backend): the form shows no figure.
  final CertificateCosts? certificateCosts;

  /// The labs taking pieces, the main lab first.
  final List<LabRef> labs;

  /// The enabled type of [category] named [nameEn], if Dahab accepts it now.
  PieceTypeRef? pieceType(String category, String nameEn) {
    for (final t in pieceTypes) {
      if (t.category == category && t.nameEn.toLowerCase() == nameEn.toLowerCase()) return t;
    }
    return null;
  }
}
