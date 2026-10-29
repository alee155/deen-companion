import '../../../core/error/failures.dart';

/// Backend error codes the special-days screens react to. Anything else is
/// [other]; its message still reaches the user.
enum SpecialDaysErrorCode {
  /// 403: this account is not eligible (male, or no gender set).
  notAvailable('EXEMPTION_NOT_AVAILABLE'),

  /// 409 on start: not all five photos are in.
  imagesRequired('EXEMPTION_IMAGES_REQUIRED'),

  /// 409 on start: already running.
  alreadyActive('EXEMPTION_ALREADY_ACTIVE'),

  /// 409 on start: the last period ended too recently; see `canStartAt`.
  tooSoon('EXEMPTION_TOO_SOON'),

  /// 409 on start: the account has no prayer times (no location yet).
  timesNotSynced('PRAYER_TIMES_NOT_SYNCED'),

  /// 409 on upload: the photo matches one already used.
  imageDuplicate('EXEMPTION_IMAGE_DUPLICATE'),

  /// 409 on upload or delete: photos can't change while special days run.
  active('EXEMPTION_ACTIVE'),

  /// 413, or the app's own limit.
  fileTooLarge('FILE_TOO_LARGE'),
  other('');

  final String wire;
  const SpecialDaysErrorCode(this.wire);

  static SpecialDaysErrorCode parse(String? code) => values.firstWhere(
    (c) => c.wire.isNotEmpty && c.wire == code,
    orElse: () => other,
  );
}

class SpecialDaysFailure extends ServerFailure {
  final SpecialDaysErrorCode code;
  final int? statusCode;
  const SpecialDaysFailure(
    super.message, {
    this.code = SpecialDaysErrorCode.other,
    this.statusCode,
  });
}
