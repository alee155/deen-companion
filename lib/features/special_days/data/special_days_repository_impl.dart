import 'dart:io';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/flow_log.dart';
import '../../../core/utils/logger.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import '../domain/special_days.dart';
import '../domain/special_days_failure.dart';
import '../domain/special_days_repository.dart';
import 'special_days_remote_datasource.dart';

const _tag = 'SPECIAL DAYS';

class SpecialDaysRepositoryImpl implements SpecialDaysRepository {
  final SpecialDaysRemoteDataSource remote;
  const SpecialDaysRepositoryImpl(this.remote);

  @override
  Future<Result<SpecialDays>> getState() => _guard('getState', remote.getState);

  @override
  Future<Result<Map<PrayerName, SpecialDayImage>>> getImages() =>
      _guard('getImages', remote.getImages);

  @override
  Future<Result<SpecialDays>> setActive(bool active) =>
      _guard('setActive($active)', () => remote.setActive(active));

  @override
  Future<Result<SpecialDays>> uploadImage(
    PrayerName prayer,
    String path,
  ) async {
    // Refuse here what the server would refuse after an upload.
    final file = File(path);
    if (!await file.exists()) {
      return const Error(UnexpectedFailure('Couldn’t read the photo.'));
    }
    if (await file.length() > SpecialDaysRepository.maxPhotoBytes) {
      return const Error(
        SpecialDaysFailure(
          'That photo is too large. The limit is 5 MB.',
          code: SpecialDaysErrorCode.fileTooLarge,
          statusCode: 413,
        ),
      );
    }
    return _guard(
      'uploadImage(${prayer.name})',
      () => remote.uploadImage(prayer, path),
    );
  }

  @override
  Future<Result<SpecialDays>> removeImage(PrayerName prayer) =>
      _guard('removeImage(${prayer.name})', () => remote.removeImage(prayer));

  Future<Result<T>> _guard<T>(String op, Future<T> Function() body) async {
    try {
      final data = await body();
      FlowLog.log(_tag, '$op OK');
      return Success(data);
    } on NetworkException {
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      FlowLog.error(_tag, '$op: SERVER ERROR', '${e.statusCode} ${e.code}');
      var code = SpecialDaysErrorCode.parse(e.code);
      if (code == SpecialDaysErrorCode.other && e.statusCode == 413) {
        code = SpecialDaysErrorCode.fileTooLarge;
      }
      return Error(
        SpecialDaysFailure(
          e.message ?? const ServerFailure().message,
          code: code,
          statusCode: e.statusCode,
        ),
      );
    } catch (e, st) {
      AppLogger.e('SpecialDaysRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
