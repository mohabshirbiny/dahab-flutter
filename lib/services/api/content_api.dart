import '../../core/text/text_bundle.dart';
import 'api_client.dart';

/// The published app texts (backend spec 019, `GET /reference/app-texts`): a public read.
/// [appTexts] sends the saved version tag as `If-None-Match`; the server answers 304 when
/// nothing was published and no setting behind a placeholder moved, and then this returns null.
class ContentApi {
  ContentApi(this._client);

  final ApiClient _client;

  Future<TextBundle?> appTexts({String? tag}) async {
    final res = await _client.getConditional('/reference/app-texts', etag: tag);
    if (res.status == 304) return null;
    final data = res.json?['data'];
    if (data is! Map) return null;
    return TextBundle.fromJson(data.cast<String, dynamic>(), tag: res.etag);
  }
}
