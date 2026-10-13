import 'dart:typed_data';
import '../../../../core/usecase/usecase.dart';
import '../entities/snap_draft.dart';

/// Image work kept out of the UI: preparing a fresh capture for editing and
/// compressing the final crop for upload.
abstract class SnapImageProcessor {
  /// Reads the captured photo and returns bytes sized for smooth cropping
  /// (full-resolution camera frames are slow to crop on the UI thread).
  Future<Result<Uint8List>> prepareForEditing(String capturedPath);

  /// Compresses the cropped image for upload and writes it to a temp file.
  Future<Result<PreparedImage>> compressForUpload(Uint8List cropped);

  /// Deletes temp files created by this processor (best effort).
  Future<void> cleanUp(Iterable<String> paths);
}
