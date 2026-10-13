import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/logger.dart';
import '../domain/entities/snap_draft.dart';
import '../domain/repositories/snap_image_processor.dart';

/// [SnapImageProcessor] backed by `flutter_image_compress` (native encoders).
///
/// Notes on the package: `minWidth`/`minHeight` act as a *bound* — the image
/// is scaled down (never up) until its shorter side reaches that value, keeping
/// the aspect ratio. Output is JPEG and EXIF (including GPS) is dropped unless
/// `keepExif` is set, which is what we want for privacy.
class FlutterSnapImageProcessor implements SnapImageProcessor {
  const FlutterSnapImageProcessor();

  /// Short-side target for editing: sharp enough to crop precisely, small
  /// enough to stay fast.
  static const editShortSide = 1600;
  static const editQuality = 92;

  /// Short-side target for the upload. 1080 keeps snaps crisp on phone screens.
  static const uploadShortSide = 1080;
  static const uploadQuality = 80;

  @override
  Future<Result<Uint8List>> prepareForEditing(String capturedPath) async {
    try {
      final bytes = await FlutterImageCompress.compressWithFile(
        capturedPath,
        minWidth: editShortSide,
        minHeight: editShortSide,
        quality: editQuality,
        // Bake the camera's EXIF rotation in, so crop/preview are upright.
        autoCorrectionAngle: true,
      );
      if (bytes == null || bytes.isEmpty) {
        return const Error(UnexpectedFailure("Couldn't read the photo."));
      }
      return Success(bytes);
    } catch (e, st) {
      AppLogger.e('SnapImageProcessor: prepareForEditing failed', e, st);
      return const Error(UnexpectedFailure("Couldn't read the photo."));
    }
  }

  @override
  Future<Result<PreparedImage>> compressForUpload(Uint8List cropped) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        cropped,
        minWidth: uploadShortSide,
        minHeight: uploadShortSide,
        quality: uploadQuality,
        autoCorrectionAngle: false, // already upright after editing
        keepExif: false,
      );
      final file = File(
        '${Directory.systemTemp.path}/snap_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(out, flush: true);
      return Success(
        PreparedImage(
          path: file.path,
          originalBytes: cropped.length,
          compressedBytes: out.length,
        ),
      );
    } catch (e, st) {
      AppLogger.e('SnapImageProcessor: compressForUpload failed', e, st);
      return const Error(UnexpectedFailure("Couldn't prepare the photo."));
    }
  }

  @override
  Future<void> cleanUp(Iterable<String> paths) async {
    for (final p in paths) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Temp files; the OS reclaims them eventually.
      }
    }
  }
}
