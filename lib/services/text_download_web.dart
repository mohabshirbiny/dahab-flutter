import 'dart:js_interop';

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
