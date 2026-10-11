/// What is stopped or paused, and what customers can see (backend spec 019 US7,
/// `GET /reference/controls`). Read with the text bundle; anything missing means nothing is off.
class AppControls {
  const AppControls({this.stopped = false, this.stopMessage = const ControlMessage(), this.categories = const [], this.visibility = const {}});

  /// Everything is stopped: a banner, and no new listing, buy request or withdrawal.
  final bool stopped;
  final ControlMessage stopMessage;
  final List<CategoryPause> categories;

  /// `rapaport_reference`, `payout_averages`, `listing_stats`, `sharing`. Shown unless the server says false.
  final Map<String, bool> visibility;

  static const none = AppControls();

  bool shows(String item) => visibility[item] ?? true;

  CategoryPause? of(String category) {
    for (final c in categories) {
      if (c.category == category) return c;
    }
    return null;
  }

  factory AppControls.fromJson(Map<String, dynamic> json) {
    final stop = json['stop_everything'];
    final cats = <CategoryPause>[];
    final rawCats = json['categories'];
    if (rawCats is List) {
      for (final c in rawCats) {
        if (c is Map && c['category'] is String && c['level'] is String) {
          cats.add(CategoryPause(c['category'] as String, c['level'] as String, ControlMessage.fromJson(c['message'])));
        }
      }
    }
    final vis = <String, bool>{};
    final rawVis = json['visibility'];
    if (rawVis is Map) {
      rawVis.forEach((k, v) {
        if (k is String && v is bool) vis[k] = v;
      });
    }
    return AppControls(
      stopped: stop is Map && stop['active'] == true,
      stopMessage: stop is Map ? ControlMessage.fromJson(stop['message']) : const ControlMessage(),
      categories: cats,
      visibility: vis,
    );
  }
}

class CategoryPause {
  const CategoryPause(this.category, this.level, this.message);

  final String category;
  final String level;
  final ControlMessage message;
}

/// What staff wrote for customers, in both languages.
class ControlMessage {
  const ControlMessage({this.en = '', this.ar = ''});

  final String en;
  final String ar;

  String text({required bool arabic}) => (arabic ? (ar.isNotEmpty ? ar : en) : (en.isNotEmpty ? en : ar));

  factory ControlMessage.fromJson(Object? json) {
    if (json is Map) return ControlMessage(en: json['en'] is String ? json['en'] as String : '', ar: json['ar'] is String ? json['ar'] as String : '');
    return const ControlMessage();
  }
}
