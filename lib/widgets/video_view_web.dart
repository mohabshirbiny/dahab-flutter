import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// A `<video>` with the browser's own controls, playing the downloaded bytes.
///
/// The bytes are played from a blob, never from the API's address: the media
/// endpoints stream without byte ranges, and Safari on the iPhone refuses to
/// play a video it cannot ask for in ranges.
class VideoView extends StatefulWidget {
  const VideoView({super.key, required this.bytes, required this.contentType});

  final List<int> bytes;
  final String contentType;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late final String _url = web.URL.createObjectURL(
    web.Blob(
      [Uint8List.fromList(widget.bytes).toJS].toJS,
      web.BlobPropertyBag(type: widget.contentType),
    ),
  );

  @override
  void dispose() {
    web.URL.revokeObjectURL(_url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'video',
      onElementCreated: (Object element) {
        final video = element as web.HTMLVideoElement
          ..src = _url
          ..controls = true
          ..playsInline = true
          ..preload = 'metadata';
        video.setAttribute('playsinline', '');
        video.style
          ..width = '100%'
          ..height = '100%'
          ..objectFit = 'contain'
          ..backgroundColor = '#000';
      },
    );
  }
}
