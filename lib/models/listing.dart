/// One of the seller's own listings, as `GET /customer/me/listings` sends it
/// (backend spec 010, contract "Listing (seller view)"). Money and weight are
/// kept as the backend's decimal strings; the app formats them and never
/// computes with them.
library;

import 'buy_request.dart';

/// A `listing_state` value. The backend has more states than this app acts on
/// (at inspection, sold, …, for later features), so anything unknown is kept
/// and shown as "in progress". Reserved (buyers in line) and accepted (a buyer
/// chosen) come with buy requests (spec 011).
enum ListingState {
  draft,
  inReview,
  changesRequested,
  live,
  reserved,
  accepted,
  rejected,
  withdrawn,
  suspendedHold,
  other;

  static ListingState parse(String? value) => switch (value) {
    'draft' => draft,
    'in_review' => inReview,
    'changes_requested' => changesRequested,
    'live' => live,
    'reserved' => reserved,
    'accepted' => accepted,
    'rejected' => rejected,
    'withdrawn' => withdrawn,
    'suspended_hold' => suspendedHold,
    _ => other,
  };
}

/// A photo, the video, the invoice or the stone certificate of a listing.
class ListingMedia {
  const ListingMedia({required this.id, required this.kind, required this.isPrivate, required this.mime, required this.position, required this.url});

  final String id;

  /// `photo`, `video`, `invoice` or `stone_certificate`.
  final String kind;
  final bool isPrivate;
  final String mime;
  final int position;

  /// A path on the API that streams the file (`/api/v1/…/media/{id}`).
  final String url;

  factory ListingMedia.fromJson(Map<String, dynamic> j) => ListingMedia(
    id: '${j['id']}',
    kind: '${j['kind']}',
    isPrivate: j['is_private'] == true,
    mime: '${j['mime'] ?? ''}',
    position: (j['position'] as num?)?.toInt() ?? 0,
    url: '${j['url'] ?? ''}',
  );
}

class Listing {
  const Listing({
    required this.id,
    required this.state,
    required this.rawState,
    required this.category,
    required this.pieceTypeId,
    required this.typeNameEn,
    required this.typeNameAr,
    required this.karat,
    required this.weight,
    required this.makingPerGram,
    required this.askingPrice,
    required this.description,
    required this.media,
    required this.branchIds,
    this.branchNames = const [],
    this.branchNamesAr = const [],
    required this.currentPrice,
    required this.youWouldReceive,
    required this.staffMessage,
    required this.createdAt,
    required this.listedAt,
    required this.canEdit,
    required this.canSubmit,
    required this.canWithdraw,
    this.queueCount = 0,
    this.order,
  });

  /// Buyers in line (spec 011).
  final int queueCount;

  /// The latest order on the piece, once a buyer was accepted (spec 011).
  final OrderSummary? order;

  final String id;
  final ListingState state;
  final String rawState;

  /// `gold`, `diamond` or `gold_with_diamond`.
  final String category;
  final int pieceTypeId;
  final String typeNameEn;
  final String typeNameAr;
  final int? karat;

  /// Grams, e.g. `8.000`; null for a pure diamond.
  final String? weight;
  final String? makingPerGram;
  final String? askingPrice;
  final String? description;
  final List<ListingMedia> media;
  final List<int> branchIds;
  final List<String> branchNames;
  final List<String> branchNamesAr;

  /// What a buyer would pay now; null when it cannot be quoted.
  final String? currentPrice;

  /// What would reach the seller after commission and VAT (indicative).
  final String? youWouldReceive;

  /// What Dahab wrote when it asked for changes, rejected or took the piece down.
  final String? staffMessage;
  final DateTime createdAt;
  final DateTime? listedAt;
  final bool canEdit;
  final bool canSubmit;
  final bool canWithdraw;

  List<ListingMedia> get photos => media.where((m) => m.kind == 'photo').toList();

  ListingMedia? mediaOf(String kind) {
    for (final m in media) {
      if (m.kind == kind) return m;
    }
    return null;
  }

  factory Listing.fromJson(Map<String, dynamic> j) {
    final type = (j['piece_type'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Listing(
      id: '${j['id']}',
      state: ListingState.parse(j['state'] as String?),
      rawState: '${j['state'] ?? ''}',
      category: '${j['category'] ?? 'gold'}',
      pieceTypeId: (type['id'] as num?)?.toInt() ?? 0,
      typeNameEn: '${type['name_en'] ?? ''}',
      typeNameAr: '${type['name_ar'] ?? ''}',
      karat: (j['karat'] as num?)?.toInt(),
      weight: j['stated_weight_g'] as String?,
      makingPerGram: j['making_charge_per_g'] as String?,
      askingPrice: j['asking_price'] as String?,
      description: j['description'] as String?,
      media: [for (final m in (j['media'] as List? ?? const [])) ListingMedia.fromJson((m as Map).cast<String, dynamic>())],
      branchIds: [for (final b in (j['branch_options'] as List? ?? const [])) ((b as Map)['id'] as num).toInt()],
      branchNames: [for (final b in (j['branch_options'] as List? ?? const [])) '${(b as Map)['name_en']}'],
      branchNamesAr: [for (final b in (j['branch_options'] as List? ?? const [])) '${(b as Map)['name_ar']}'],
      currentPrice: j['current_price'] as String?,
      youWouldReceive: j['you_would_receive'] as String?,
      staffMessage: j['staff_message'] as String?,
      createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
      listedAt: j['listed_at'] == null ? null : DateTime.tryParse('${j['listed_at']}')?.toLocal(),
      canEdit: j['can_edit'] == true,
      canSubmit: j['can_submit'] == true,
      canWithdraw: j['can_withdraw'] == true,
      queueCount: (j['queue_count'] as num?)?.toInt() ?? 0,
      order: OrderSummary.fromJson(j['order']),
    );
  }
}
