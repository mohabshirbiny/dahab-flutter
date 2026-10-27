import 'package:flutter/widgets.dart';

/// Non-web fallback (used by `flutter test` on the VM): nothing plays.
class VideoView extends StatelessWidget {
  const VideoView({super.key, required this.bytes, required this.contentType});

  final List<int> bytes;
  final String contentType;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
