import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// `dl(name, text)` — save a generated text file in the browser. Nothing is
/// fetched; the file is built locally from mock data.
bool downloadText(String filename, String text) {
  try {
    final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: 'text/plain;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    a.click();
    Future.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}

/// Save a file the backend sent (backend spec 016: a tax invoice or credit note PDF).
bool downloadBytes(String filename, List<int> bytes, String mime) {
  try {
    final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = filename;
    a.click();
    Future.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}
