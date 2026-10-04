import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils/idempotency.dart';
import '../models/account.dart';
import '../models/listing.dart';
import '../models/reference.dart';
import 'api/api_client.dart' show UploadFile;
import 'live_rates.dart';
import 'media_picker.dart';
import 'pricing.dart';
import 'repositories.dart';

/// The piece being listed, shared by Sell steps 1–3 and the weight guide.
///
/// Since backend spec 010 the draft is sent for real: the files are uploaded,
/// the listing is created (or, when fixing one, edited) and then sent for
/// review ([send]). The on-screen "You receive" figure is still the
/// prototype's estimate; the backend's own figure comes back on the listing.
class SellDraft extends ChangeNotifier {
  SellType type = SellType.gold;
  int karat = 21;

  /// A `piece_type` id from the reference data; set by [syncWith].
  int? pieceTypeId;
  double weight = 8;
  double making = 300;

  // A guide for the stone's price only; the listing carries the asking price.
  double carat = 0.7;
  double clarity = 1; // VS
  double cut = 1; // Very good
  double stoneAsk = 30000;
  bool _stoneTouched = false;
  double totalAsk = 90000;

  String cert = 'igi';

  PromoCode? promo;

  /// Files picked on this device, by slot key (`full`, `hall`, `stone`,
  /// `x0`…, `inv`, `video`, `cert`).
  final Map<String, UploadFile> files = {};

  /// Upload tokens of [files] already sent, by slot key. Single use.
  final Map<String, String> tokens = {};

  /// Media already on the listing being fixed, by slot key.
  final Map<String, ListingMedia> kept = {};
  final Set<String> _removedMediaIds = {};
  int extraPhotos = 0;

  String description = '';

  /// Branches the seller is willing to bring the piece to.
  final Set<int> branchIds = {};

  /// The listing being fixed, or one created here that is not sent yet.
  Listing? editing;

  final Map<String, (String, String)> _keys = {};

  static const maxPhotos = 6;

  /// The backend's `category`.
  String get category => switch (type) {
    SellType.gold => 'gold',
    SellType.diamond => 'diamond',
    SellType.mixed => 'gold_with_diamond',
  };

  /// Makes the draft valid against what Dahab accepts now. Does not notify:
  /// it is called while the sell screens build.
  void syncWith(SellReference ref) {
    final types = ref.pieceTypes.where((t) => t.category == category);
    if (!types.any((t) => t.id == pieceTypeId)) pieceTypeId = types.isEmpty ? null : types.first.id;
    if (ref.karats.isNotEmpty && !ref.karats.contains(karat)) karat = ref.karats.contains(21) ? 21 : ref.karats.first;
    branchIds.removeWhere((id) => !ref.branches.any((b) => b.id == id));
  }

  double get suggestedStone => Pricing.suggestedStone(carat, clarity, cut);

  /// The mock rate for the draft's karat; a karat the mock feed does not
  /// know is derived from 24K by purity.
  int rateFor(LiveRates rates) => Pricing.baseRates.containsKey(karat) ? rates.rate(karat) : (rates.rate(24) * karat / 24).round();

  SellQuote quote(int rate) => Pricing.sell(type: type, rate: rate, weight: weight, makingPerGram: making, stoneAsk: stoneAsk, totalAsk: totalAsk, promoOff: promo?.off ?? 0);

  void _syncStone() {
    if (!_stoneTouched && type == SellType.diamond) {
      stoneAsk = ((suggestedStone / 500).round() * 500).toDouble().clamp(0, 150000);
    }
  }

  void update(void Function(SellDraft d) change, {bool resetsStone = false, bool touchesStone = false}) {
    change(this);
    if (resetsStone) _stoneTouched = false;
    if (touchesStone) _stoneTouched = true;
    if (extraPhotos > maxExtraPhotos) extraPhotos = maxExtraPhotos;
    _syncStone();
    notifyListeners();
  }

  // ---- photos (`photoSpec`) ----
  List<PhotoSlot> get photoSlots => [
    const PhotoSlot('full', 'Full piece', required: true),
    const PhotoSlot('hall', 'Hallmark stamp', required: true),
    if (type != SellType.gold) const PhotoSlot('stone', 'Stone close-up', required: true, icon: 'diamond'),
    const PhotoSlot('inv', 'Invoice', icon: 'receipt', hint: 'Helps it sell'),
    for (var i = 0; i < extraPhotos; i++) PhotoSlot('x$i', 'Another angle'),
  ];

  /// The photo slots in display order (the invoice is not a photo).
  List<String> get _photoKeys => ['full', 'hall', if (type != SellType.gold) 'stone', for (var i = 0; i < extraPhotos; i++) 'x$i'];

  int get maxExtraPhotos => maxPhotos - (type == SellType.gold ? 2 : 3);

  int get requiredCount => photoSlots.where((s) => s.required).length;
  int get requiredAdded => photoSlots.where((s) => s.required && has(s.key)).length;

  bool has(String key) => files.containsKey(key) || kept.containsKey(key);

  static MediaKind kindOf(String key) => switch (key) {
    'inv' => MediaKind.invoice,
    'video' => MediaKind.video,
    'cert' => MediaKind.certificate,
    _ => MediaKind.photo,
  };

  /// Puts a picked file in a slot, replacing what was there.
  void setFile(String key, UploadFile file) {
    final old = kept.remove(key);
    if (old != null && old.kind == 'photo') _removedMediaIds.add(old.id);
    files[key] = file;
    tokens.remove(key);
    notifyListeners();
  }

  /// Returns false when the six-photo cap is reached.
  bool addExtraPhoto() {
    if (extraPhotos >= maxExtraPhotos) return false;
    extraPhotos++;
    notifyListeners();
    return true;
  }

  void toggleBranch(int id) {
    branchIds.contains(id) ? branchIds.remove(id) : branchIds.add(id);
    notifyListeners();
  }

  /// Forget upload tokens the backend no longer accepts; the files are sent again.
  void forgetTokens() => tokens.clear();

  /// Start a new listing from scratch.
  void reset() {
    type = SellType.gold;
    karat = 21;
    pieceTypeId = null;
    weight = 8;
    making = 300;
    carat = 0.7;
    clarity = 1;
    cut = 1;
    stoneAsk = 30000;
    _stoneTouched = false;
    totalAsk = 90000;
    cert = 'igi';
    promo = null;
    files.clear();
    tokens.clear();
    kept.clear();
    _removedMediaIds.clear();
    extraPhotos = 0;
    description = '';
    branchIds.clear();
    editing = null;
    _keys.clear();
    notifyListeners();
  }

  /// Open one of the seller's listings to fix it (draft or changes requested).
  void loadFrom(Listing l) {
    reset();
    type = switch (l.category) {
      'diamond' => SellType.diamond,
      'gold_with_diamond' => SellType.mixed,
      _ => SellType.gold,
    };
    karat = l.karat ?? karat;
    pieceTypeId = l.pieceTypeId;
    weight = (double.tryParse(l.weight ?? '') ?? weight).clamp(0.5, 50).toDouble();
    making = (double.tryParse(l.makingPerGram ?? '') ?? making).clamp(0, 1000).toDouble();
    final ask = double.tryParse(l.askingPrice ?? '');
    if (ask != null && type == SellType.diamond) {
      stoneAsk = ask.clamp(0, 150000).toDouble();
      _stoneTouched = true;
    }
    if (ask != null && type == SellType.mixed) totalAsk = ask.clamp(0, 300000).toDouble();
    description = l.description ?? '';
    branchIds.addAll(l.branchIds);
    _adopt(l);
    if (type != SellType.gold) cert = kept.containsKey('cert') ? 'other' : 'none';
    notifyListeners();
  }

  /// The listing now exists on the backend with this media: nothing is left to upload.
  void _adopt(Listing l) {
    editing = l;
    files.clear();
    tokens.clear();
    kept.clear();
    _removedMediaIds.clear();
    final photos = l.photos..sort((a, b) => a.position.compareTo(b.position));
    final fixed = type == SellType.gold ? 2 : 3;
    extraPhotos = (photos.length - fixed).clamp(0, maxExtraPhotos);
    final keys = _photoKeys;
    for (var i = 0; i < photos.length && i < keys.length; i++) {
      kept[keys[i]] = photos[i];
    }
    for (final (key, kind) in const [('inv', 'invoice'), ('video', 'video'), ('cert', 'stone_certificate')]) {
      final m = l.mediaOf(kind);
      if (m != null) kept[key] = m;
    }
  }

  bool _inUse(String key) => switch (key) {
    'inv' || 'video' => true,
    'cert' => type != SellType.gold && cert != 'none',
    _ => _photoKeys.contains(key),
  };

  String _key(String step, String payload) {
    final k = _keys[step];
    if (k == null || k.$1 != payload) _keys[step] = (payload, newIdempotencyKey());
    return _keys[step]!.$2;
  }

  Map<String, dynamic> _fields() => {
    'piece_type_id': pieceTypeId,
    if (type != SellType.diamond) 'karat_code': karat,
    if (type != SellType.diamond) 'stated_weight_g': weight.toStringAsFixed(1),
    if (type == SellType.gold) 'making_charge_per_g': making.round().toString(),
    if (type == SellType.diamond) 'asking_price': stoneAsk.round().toString(),
    if (type == SellType.mixed) 'asking_price': totalAsk.round().toString(),
    'description': description.trim(),
    'branch_option_ids': branchIds.toList()..sort(),
  };

  List<String> get _newPhotoTokens => [
    for (final k in _photoKeys)
      if (tokens.containsKey(k)) tokens[k]!,
  ];

  /// Uploads what is new, creates or edits the listing, and sends it for
  /// review. Safe to call again after a failure: what already succeeded is
  /// not repeated, and each write reuses its idempotency key.
  Future<Listing> send(ListingsRepository repo, SellReference ref) async {
    for (final key in files.keys.toList()) {
      if (tokens.containsKey(key) || !_inUse(key)) continue;
      tokens[key] = await repo.uploadMedia(kindOf(key).purpose, files[key]!);
    }

    final certOn = _inUse('cert');
    Listing l;
    if (editing == null) {
      final body = {
        'category': category,
        ..._fields(),
        'photo_tokens': _newPhotoTokens,
        if (tokens.containsKey('video')) 'video_token': tokens['video'],
        if (tokens.containsKey('inv')) 'invoice_token': tokens['inv'],
        if (certOn && tokens.containsKey('cert')) 'stone_certificate_token': tokens['cert'],
        'ownership_declaration_accepted': true,
        'ownership_legal_doc_id': ref.declaration.id,
      };
      l = await repo.create(body, idempotencyKey: _key('create', jsonEncode(body)));
    } else {
      final id = editing!.id;
      final keys = _photoKeys;
      final before = {for (final m in editing!.photos) m.id};
      final dropped = {
        ..._removedMediaIds,
        // Photos in slots that no longer exist (fewer "another angle" slots).
        for (final e in kept.entries)
          if (e.value.kind == 'photo' && !keys.contains(e.key)) e.value.id,
      };
      final body = {
        ..._fields(),
        if (_newPhotoTokens.isNotEmpty) 'add_photo_tokens': _newPhotoTokens,
        if (dropped.isNotEmpty) 'remove_media_ids': dropped.toList()..sort(),
        if (tokens.containsKey('video')) 'video_token': tokens['video'],
        if (tokens.containsKey('inv')) 'invoice_token': tokens['inv'],
        if (certOn && tokens.containsKey('cert')) 'stone_certificate_token': tokens['cert'],
        if (!certOn && kept.containsKey('cert')) 'stone_certificate_token': null,
      };
      l = await repo.update(id, body, idempotencyKey: _key('update', jsonEncode(body)));

      // New photos are added at the end; put every photo back in its slot.
      final added = [
        for (final m in l.photos)
          if (!before.contains(m.id)) m.id,
      ];
      var next = 0;
      final wanted = <String>[
        for (final k in keys)
          if (kept[k] != null) kept[k]!.id else if (tokens.containsKey(k) && next < added.length) added[next++],
      ];
      final now = [for (final m in l.photos) m.id];
      if (wanted.length == now.length && !listEquals(wanted, now)) {
        final order = {'photo_order': wanted};
        l = await repo.update(id, order, idempotencyKey: _key('order', jsonEncode(order)));
      }
    }
    _adopt(l);

    return repo.submit(l.id, idempotencyKey: _key('submit', l.id));
  }
}

class PhotoSlot {
  const PhotoSlot(this.key, this.title, {this.required = false, this.icon = 'camera', this.hint});

  final String key;
  final String title;
  final bool required;
  final String icon;
  final String? hint;
}
