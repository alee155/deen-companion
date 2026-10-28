/// How long a recipient can view a snap once opened. The server accepts 1 to
/// 10 seconds (`viewDurationSeconds`), so nothing longer is offered.
class SnapViewTimer {
  SnapViewTimer._();

  static const options = [3, 5, 10];
  static const defaultSeconds = 5;
}

/// The image after cropping and compression, ready to upload.
class PreparedImage {
  /// JPEG file on disk (temporary).
  final String path;
  final int originalBytes;
  final int compressedBytes;

  const PreparedImage({
    required this.path,
    required this.originalBytes,
    required this.compressedBytes,
  });

  /// 0..1 — how much smaller the upload is than the cropped source.
  double get savedFraction =>
      originalBytes == 0 ? 0 : 1 - compressedBytes / originalBytes;
}

/// Everything the "send snap" API will need. A snap goes to groups, and
/// everyone in a chosen group receives it: the app never picks individual
/// members, so a draft names [groupIds] and nothing more granular.
class SnapDraft {
  /// The groups to send to; at least one.
  final List<String> groupIds;
  final String imagePath;
  final int viewSeconds;
  final String? caption;

  const SnapDraft({
    required this.groupIds,
    required this.imagePath,
    required this.viewSeconds,
    this.caption,
  });
}

/// What the backend reports for a sent snap. Minimal until the API exists.
class SentSnap {
  final String id;
  const SentSnap({required this.id});
}
