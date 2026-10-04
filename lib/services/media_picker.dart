import 'package:file_picker/file_picker.dart';

import 'api/api_client.dart' show UploadFile;

/// What a listing file is for. The limits mirror the backend's
/// (`config/dahab-listings.php`, spec 010), which re-checks every upload.
enum MediaKind {
  photo('listing_photo', ['jpg', 'jpeg', 'png', 'webp'], 8),
  video('listing_video', ['mp4', 'mov', 'webm'], 50),
  invoice('listing_invoice', ['jpg', 'jpeg', 'png', 'webp', 'pdf'], 8),
  certificate('stone_certificate', ['jpg', 'jpeg', 'png', 'webp', 'pdf'], 8),

  /// Spec 014: a photo with a report, and the ID of the person collecting.
  disputePhoto('dispute_photo', ['jpg', 'jpeg', 'png', 'webp'], 8),
  proxyId('proxy_id', ['jpg', 'jpeg', 'png', 'webp'], 8);

  const MediaKind(this.purpose, this.extensions, this.maxMegabytes);

  /// The `purpose` of `POST /customer/me/uploads`.
  final String purpose;
  final List<String> extensions;
  final int maxMegabytes;
}

/// The outcome of asking the customer for a file: the file, or why not.
class PickedMedia {
  const PickedMedia.file(UploadFile this.file) : error = null;
  const PickedMedia.refused(String this.error) : file = null;

  final UploadFile? file;

  /// An English sentence to show (translated by the caller).
  final String? error;
}

/// Asks the customer for a file. An interface so widget tests can hand the
/// sell flow a file without a platform file dialog.
abstract interface class MediaPicker {
  /// Null when the customer closed the dialog without choosing.
  Future<PickedMedia?> pick(MediaKind kind);
}

/// The real picker: the platform's file dialog.
class FilePickerMediaPicker implements MediaPicker {
  const FilePickerMediaPicker();

  @override
  Future<PickedMedia?> pick(MediaKind kind) async {
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: kind.extensions);
    if (picked == null) return null;

    final ext = (picked.extension ?? '').toLowerCase();
    if (!kind.extensions.contains(ext)) {
      return PickedMedia.refused(switch (kind) {
        MediaKind.photo || MediaKind.disputePhoto || MediaKind.proxyId => 'Use a JPG, PNG or WEBP photo.',
        MediaKind.video => 'Use an MP4, MOV or WEBM video.',
        _ => 'Use a photo (JPG, PNG, WEBP) or a PDF.',
      });
    }

    final bytes = await picked.readAsBytes();
    if (bytes.length > kind.maxMegabytes * 1024 * 1024) {
      return PickedMedia.refused(kind == MediaKind.video ? 'That video is larger than 50 MB.' : 'That file is larger than 8 MB.');
    }

    return PickedMedia.file(UploadFile(field: 'file', filename: picked.name, bytes: bytes, contentType: contentTypeOf(ext)));
  }

  static String contentTypeOf(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    _ => 'image/jpeg',
  };
}
