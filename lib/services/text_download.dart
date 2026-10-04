/// Saves a generated text file in the browser. Only works on web; elsewhere
/// (unit tests) it reports that nothing was saved.
library;

export 'text_download_stub.dart' if (dart.library.js_interop) 'text_download_web.dart';
