/// Non-web fallback (used by `flutter test` on the VM).
bool downloadText(String filename, String text) => false;

/// Non-web fallback for a downloaded file (backend spec 016 PDFs).
bool downloadBytes(String filename, List<int> bytes, String mime) => false;
