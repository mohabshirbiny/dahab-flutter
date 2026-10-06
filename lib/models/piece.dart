import 'listing.dart';

/// A listed piece of jewellery, as shown on the Home / Browse / Saved grids.
///
/// Since backend spec 010 the market comes from `GET /market/listings`
/// ([Piece.fromMarketJson]); saved pieces are still mock. The market never
/// says who the seller is — only whether the piece is the signed-in
/// customer's own ([mine]).
class Piece {
  const Piece({
    required this.id,
    required this.title,
    required this.price,
    required this.karat,
    required this.weight,
    required this.kind,
    required this.specLine,
    required this.feeLine,
    this.makingPerGram,
    this.hasStones = false,
    this.mine = false,
    this.priceAvailable = true,
    this.priceIndicative = true,
    this.photoPath,
    this.titleAr,
  });

  final String id;

  /// e.g. "Gold ring, 21K".
  final String title;

  /// The same title in Arabic, for pieces from the API (mock pieces are
  /// translated through the dictionary instead).
  final String? titleAr;

  /// Current price in EGP (follows the gold rate until a request is sent).
  /// 0 when [priceAvailable] is false.
  final int price;

  /// False when the backend cannot quote a price right now (no gold price).
  final bool priceAvailable;

  /// True for gold: the price moves with the gold rate. False for a fixed
  /// asking price (diamond, gold with diamond).
  final bool priceIndicative;
  final int karat;
  final double weight;

  /// ring, earrings, chain, bangle, necklace, …
  final String kind;

  /// Second line on the card, e.g. "21K, 8.00 g" (English source string).
  final String specLine;

  /// Third line, e.g. "Making charge 250 per gram" or "Set price".
  final String feeLine;
  final int? makingPerGram;
  final bool hasStones;

  /// The signed-in user's own listing ("Yours").
  final bool mine;

  /// API path of the first photo (`/api/v1/market/listings/…/media/…`).
  final String? photoPath;

  /// A market item (backend spec 010 contract "MarketListing").
  factory Piece.fromMarketJson(Map<String, dynamic> j) {
    final type = (j['piece_type'] as Map?)?.cast<String, dynamic>() ?? const {};
    final category = '${j['category'] ?? 'gold'}';
    final karat = (j['karat'] as num?)?.toInt();
    final weight = double.tryParse('${j['weight_g'] ?? ''}') ?? 0;
    final making = double.tryParse('${j['making_charge_per_g'] ?? ''}');
    final price = double.tryParse('${j['current_price'] ?? ''}');
    final photos = (j['photos'] as List? ?? const []);
    final typeEn = '${type['name_en'] ?? 'Piece'}';
    final typeAr = '${type['name_ar'] ?? ''}';

    return Piece(
      id: '${j['id']}',
      title: pieceTitle(category, typeEn, karat),
      titleAr: pieceTitleAr(category, typeAr, karat),
      price: price?.round() ?? 0,
      priceAvailable: j['price_available'] == true && price != null,
      priceIndicative: j['price_is_indicative'] != false,
      karat: karat ?? 0,
      weight: weight,
      kind: typeEn.toLowerCase(),
      specLine: switch (category) {
        'diamond' => 'Diamond',
        'gold_with_diamond' => '${karat}K gold and diamond, ${weight.toStringAsFixed(2)} g',
        _ => '${karat}K, ${weight.toStringAsFixed(2)} g',
      },
      feeLine: making == null ? 'Set price' : 'Making charge ${making.round()} per gram',
      makingPerGram: making?.round(),
      hasStones: category != 'gold',
      mine: j['is_mine'] == true,
      photoPath: photos.isEmpty ? null : (photos.first as Map)['url'] as String?,
    );
  }
}

/// "Gold ring, 21K" / "Diamond ring" / "Gold and diamond ring, 21K".
String pieceTitle(String category, String typeEn, int? karat) {
  final lead = switch (category) {
    'diamond' => 'Diamond',
    'gold_with_diamond' => 'Gold and diamond',
    _ => 'Gold',
  };
  final name = '$lead ${typeEn.toLowerCase()}';
  return karat == null ? name : '$name, ${karat}K';
}

String pieceTitleAr(String category, String typeAr, int? karat) {
  final lead = switch (category) {
    'diamond' => 'ألماظ',
    'gold_with_diamond' => 'دهب وألماظ',
    _ => 'دهب',
  };
  final name = '$typeAr $lead'.trim();
  return karat == null ? name : '$name، عيار $karat';
}

/// Detail view of a single piece.
///
/// From the API ([PieceDetail.fromMarketJson]) only what the market returns
/// is set: since backend spec 011 that includes the queue count and the
/// indicative deposit. The prototype's extras with no backend (views, seller
/// line) stay null, so the screen leaves them out.
class PieceDetail {
  const PieceDetail({
    required this.piece,
    required this.photoCount,
    required this.description,
    this.views,
    this.requests,
    this.daysListed,
    this.queueAhead,
    this.goldRate,
    this.goldValue,
    this.makingValue,
    this.commission,
    this.deposit,
    this.origin,
    this.sellerName,
    this.photoPaths = const [],
    this.videoPath,
    this.certificatePath,
    this.invoicePath,
    this.branchNames = const [],
    this.branchNamesAr = const [],
    this.live = false,
    this.own,
    this.priceExact,
    this.depositExact,
  });

  /// The market's `current_price` exactly as sent: a buy request confirms it (spec 011).
  final String? priceExact;

  /// The market's indicative `deposit_amount` exactly as sent (spec 011).
  final String? depositExact;

  final Piece piece;
  final int photoCount;
  final String description;
  final int? views;
  final int? requests;
  final int? daysListed;
  final int? queueAhead;
  final int? goldRate;
  final int? goldValue;
  final int? makingValue;
  final int? commission;
  final int? deposit;
  final String? origin;
  final String? sellerName;

  /// API paths of the public photos, in order.
  final List<String> photoPaths;

  /// API paths of the video and the stone certificate, when the seller added them.
  final String? videoPath;
  final String? certificatePath;

  /// The private invoice: only on the owner's own view.
  final String? invoicePath;

  bool get hasVideo => videoPath != null;
  bool get hasCertificate => certificatePath != null;

  /// Branches the piece can be inspected at.
  final List<String> branchNames;
  final List<String> branchNamesAr;

  /// True when the data came from the API (spec 010), false for a mock piece.
  final bool live;

  /// The seller's own listing, when the owner opened it ([PieceDetail.fromListing]).
  final Listing? own;

  /// A market detail (backend spec 010 contract "MarketListingDetail").
  factory PieceDetail.fromMarketJson(Map<String, dynamic> j) {
    final parts = (j['price_parts'] as Map?)?.cast<String, dynamic>();
    final photos = (j['photos'] as List? ?? const []);
    final branches = (j['branch_options'] as List? ?? const []);
    final listed = DateTime.tryParse('${j['listed_at'] ?? ''}');
    int? whole(Object? v) => double.tryParse('${v ?? ''}')?.round();

    return PieceDetail(
      piece: Piece.fromMarketJson(j),
      photoCount: photos.length,
      description: '${j['description'] ?? ''}',
      daysListed: listed == null ? null : DateTime.now().difference(listed).inDays,
      queueAhead: (j['queue_count'] as num?)?.toInt(),
      deposit: whole(j['deposit_amount']),
      priceExact: j['current_price'] as String?,
      depositExact: j['deposit_amount'] as String?,
      goldRate: whole(parts?['rate_per_gram']),
      goldValue: whole(parts?['gold_value']),
      makingValue: whole(parts?['making_total']),
      photoPaths: [for (final p in photos) '${(p as Map)['url']}'],
      videoPath: (j['video'] as Map?)?['url'] as String?,
      certificatePath: (j['stone_certificate'] as Map?)?['url'] as String?,
      branchNames: [for (final b in branches) '${(b as Map)['name_en']}'],
      branchNamesAr: [for (final b in branches) '${(b as Map)['name_ar']}'],
      live: true,
    );
  }

  /// The owner's view of one of their listings, in any state (backend spec
  /// 010, `GET /customer/me/listings/{id}`).
  factory PieceDetail.fromListing(Listing l) {
    final weight = double.tryParse(l.weight ?? '') ?? 0;
    final making = double.tryParse(l.makingPerGram ?? '');
    final price = double.tryParse(l.currentPrice ?? '');
    final photos = l.photos;
    return PieceDetail(
      piece: Piece(
        id: l.id,
        title: pieceTitle(l.category, l.typeNameEn, l.karat),
        titleAr: pieceTitleAr(l.category, l.typeNameAr, l.karat),
        price: price?.round() ?? 0,
        priceAvailable: price != null,
        priceIndicative: l.category == 'gold',
        karat: l.karat ?? 0,
        weight: weight,
        kind: l.typeNameEn.toLowerCase(),
        specLine: '',
        feeLine: '',
        makingPerGram: making?.round(),
        hasStones: l.category != 'gold',
        mine: true,
        photoPath: photos.isEmpty ? null : photos.first.url,
      ),
      photoCount: photos.length,
      description: l.description ?? '',
      photoPaths: [for (final p in photos) p.url],
      videoPath: l.mediaOf('video')?.url,
      certificatePath: l.mediaOf('stone_certificate')?.url,
      invoicePath: l.mediaOf('invoice')?.url,
      branchNames: l.branchNames,
      branchNamesAr: l.branchNamesAr,
      live: true,
      own: l,
    );
  }
}

/// How the detail screen was opened (`ownerView`, `cancelledView`,
/// `buyState` in the prototype).
enum DetailView { buyer, owner, cancelled, requested, accepted }

/// A piece the customer saved (backend spec 017 FR-040). While it is on the
/// market [piece] carries it with its indicative price; once it left, only
/// the summary taken when it was saved remains.
class SavedPiece {
  const SavedPiece({required this.listingId, required this.piece, required this.title, required this.karat, required this.weight});

  final String listingId;
  final Piece? piece;
  final String title;
  final int? karat;
  final String? weight;

  bool get available => piece != null;

  factory SavedPiece.fromJson(Map<String, dynamic> j) {
    final summary = ((j['summary'] as Map?) ?? const {}).cast<String, dynamic>();
    final type = ((summary['piece_type'] as Map?) ?? const {}).cast<String, dynamic>();
    final listing = j['available'] == true && j['listing'] is Map ? Piece.fromMarketJson((j['listing'] as Map).cast<String, dynamic>()) : null;
    return SavedPiece(
      listingId: '${j['listing_id']}',
      piece: listing,
      title: '${type['name_en'] ?? 'Piece'}',
      karat: (summary['karat'] as num?)?.toInt(),
      weight: summary['weight_g'] as String?,
    );
  }
}
