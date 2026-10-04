/// Opens a listing's video, certificate or invoice in a new browser tab.
/// Only works on web; elsewhere (unit tests) nothing opens.
library;

export 'media_tab_stub.dart' if (dart.library.js_interop) 'media_tab_web.dart';
