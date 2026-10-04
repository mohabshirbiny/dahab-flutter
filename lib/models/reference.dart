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

/// An inspection branch a seller is willing to bring the piece to.
class BranchRef {
  const BranchRef({required this.id, required this.nameEn, required this.nameAr, this.addressEn = '', this.addressAr = ''});

  final int id;
  final String nameEn;
  final String nameAr;
  final String addressEn;
  final String addressAr;

  factory BranchRef.fromJson(Map<String, dynamic> j) => BranchRef(
    id: (j['id'] as num).toInt(),
    nameEn: '${j['name_en'] ?? ''}',
    nameAr: '${j['name_ar'] ?? ''}',
    addressEn: '${j['address_en'] ?? ''}',
    addressAr: '${j['address_ar'] ?? ''}',
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

/// Everything the sell flow reads before a listing exists.
class SellReference {
  const SellReference({required this.karats, required this.pieceTypes, required this.branches, required this.declaration});

  /// Enabled karat codes, in display order.
  final List<int> karats;
  final List<PieceTypeRef> pieceTypes;
  final List<BranchRef> branches;
  final LegalDoc declaration;

  /// The enabled type of [category] named [nameEn], if Dahab accepts it now.
  PieceTypeRef? pieceType(String category, String nameEn) {
    for (final t in pieceTypes) {
      if (t.category == category && t.nameEn.toLowerCase() == nameEn.toLowerCase()) return t;
    }
    return null;
  }
}
