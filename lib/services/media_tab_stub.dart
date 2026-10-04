/// Non-web fallback (used by `flutter test` on the VM): no tab opens.
class MediaTab {
  MediaTab._();

  static MediaTab? open([Uri? url]) => null;

  void show(List<int> bytes, String contentType) {}

  void close() {}
}
