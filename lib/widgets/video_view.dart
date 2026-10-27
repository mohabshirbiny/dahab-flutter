/// Plays a downloaded video inside the page (a listing's video on the piece page).
/// Only works on web; elsewhere (unit tests) a plain placeholder is shown.
library;

export 'video_view_stub.dart'
    if (dart.library.js_interop) 'video_view_web.dart';
