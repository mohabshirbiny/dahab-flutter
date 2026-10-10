/// The published texts the backend serves (`GET /reference/app-texts`, backend spec 019 R3):
/// overrides only, in both languages, plus the current values of the setting placeholders.
class TextBundle {
  const TextBundle({this.tag, this.version = 0, this.texts = const {}, this.faq = const [], this.settings = const {}});

  /// The version tag the server sent (`<bundle_version>-<settings fingerprint>`); sent back
  /// as `If-None-Match`, so an unchanged bundle answers 304.
  final String? tag;
  final int version;
  final Map<String, ({String en, String ar})> texts;
  final List<Map<String, dynamic>> faq;
  final Map<String, Object?> settings;

  static const empty = TextBundle();

  factory TextBundle.fromJson(Map<String, dynamic> json, {String? tag}) {
    final texts = <String, ({String en, String ar})>{};
    final raw = json['texts'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is Map && v['en'] is String && v['ar'] is String) {
          texts[k] = (en: v['en'] as String, ar: v['ar'] as String);
        }
      });
    }
    final settings = <String, Object?>{};
    final rawSettings = json['settings'];
    if (rawSettings is Map) {
      rawSettings.forEach((k, v) {
        if (k is String && v != null) settings[k] = v;
      });
    }
    final faq = <Map<String, dynamic>>[];
    final rawFaq = json['faq'];
    if (rawFaq is List) {
      for (final e in rawFaq) {
        if (e is Map) faq.add(e.cast<String, dynamic>());
      }
    }
    return TextBundle(
      tag: tag ?? (json['tag'] is String ? json['tag'] as String : null),
      version: json['version'] is num ? (json['version'] as num).toInt() : 0,
      texts: texts,
      faq: faq,
      settings: settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'version': version,
    'texts': {for (final e in texts.entries) e.key: {'en': e.value.en, 'ar': e.value.ar}},
    'faq': faq,
    'settings': settings,
  };
}
