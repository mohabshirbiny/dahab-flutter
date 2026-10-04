import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A browser tab showing one media file.
///
/// A public file is opened by its address, so the browser streams it. A file
/// that needs the customer's session cannot be: the tab is opened empty at
/// once (a tab opened later, after the download, is blocked as a pop-up) and
/// pointed at the downloaded bytes when they arrive ([show]).
class MediaTab {
  MediaTab._(this._window);

  final web.Window _window;

  /// Null when the browser refused to open a tab.
  static MediaTab? open([Uri? url]) {
    try {
      final w = web.window.open(url?.toString() ?? '', '_blank');
      return w == null ? null : MediaTab._(w);
    } catch (_) {
      return null;
    }
  }

  void show(List<int> bytes, String contentType) {
    final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: contentType));
    final url = web.URL.createObjectURL(blob);
    _window.location.href = url;
    // Kept long enough for a long video; freed when this page goes anyway.
    Future.delayed(const Duration(minutes: 10), () => web.URL.revokeObjectURL(url));
  }

  void close() => _window.close();
}
