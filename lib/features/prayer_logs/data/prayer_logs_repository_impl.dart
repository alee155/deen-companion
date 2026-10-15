import 'dart:io';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/logger.dart';
import '../../prayer_times/domain/entities/prayer_times.dart';
import '../domain/current_prayer.dart';
import '../domain/group_member_prayers.dart';
import '../domain/prayer_log.dart';
import '../domain/prayer_log_failure.dart';
import '../domain/prayer_logs_repository.dart';
import 'prayer_log_models.dart';
import 'prayer_logs_remote_datasource.dart';

class PrayerLogsRepositoryImpl implements PrayerLogsRepository {
  final PrayerLogsRemoteDataSource remote;
  const PrayerLogsRepositoryImpl(this.remote);

  @override
  Future<Result<CurrentPrayerState>> getCurrent() =>
      _guard('getCurrent', remote.getCurrent);

  @override
  Future<Result<List<PrayerLog>>> getLogs({String? date}) =>
      _guard('getLogs', () => remote.getLogs(date: date));

  @override
  Future<Result<List<PrayerLog>>> getLogsRange({
    required String from,
    required String to,
  }) => _guard('getLogsRange', () => remote.getLogsRange(from: from, to: to));

  @override
  Future<Result<List<GroupMemberPrayers>>> getGroupPrayers(
    String groupId, {
    String? date,
  }) => _guard(
    'getGroupPrayers',
    () => remote.getGroupPrayers(groupId, date: date),
  );

  @override
  Future<Result<PrayerLog>> logPrayer(String imagePath) async {
    // A bad request is cheaper to refuse here than to upload and bounce.
    final file = File(imagePath);
    if (!await file.exists()) {
      return const Error(UnexpectedFailure("Couldn't read the photo."));
    }
    if (await file.length() > PrayerLogsRepository.maxPhotoBytes) {
      return const Error(
        PrayerLogFailure(
          'That photo is too large. The limit is 5 MB.',
          code: PrayerLogErrorCode.fileTooLarge,
          statusCode: 413,
        ),
      );
    }
    return _guard('logPrayer', () => remote.logPrayer(imagePath));
  }

  @override
  Future<Result<void>> deleteLog(String id) =>
      _guard('deleteLog', () => remote.deleteLog(id), isDelete: true);

  Future<Result<T>> _guard<T>(
    String op,
    Future<T> Function() body, {
    bool isDelete = false,
  }) async {
    try {
      return Success(await body());
    } on NetworkException {
      return const Error(NetworkFailure());
    } on ServerException catch (e) {
      return Error(_failure(e, isDelete: isDelete));
    } catch (e, st) {
      AppLogger.e('PrayerLogsRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  PrayerLogFailure _failure(ServerException e, {required bool isDelete}) {
    var code = PrayerLogErrorCode.parse(e.code);
    if (code == PrayerLogErrorCode.other) {
      if (e.statusCode == 413) code = PrayerLogErrorCode.fileTooLarge;
      if (e.statusCode == 403) code = PrayerLogErrorCode.notGroupMember;
      // The window closed: the log can no longer be removed.
      if (isDelete && e.statusCode == 400) code = PrayerLogErrorCode.undoLocked;
    }
    return PrayerLogFailure(
      e.message ?? const ServerFailure().message,
      code: code,
      statusCode: e.statusCode,
      data: e.data,
      existingLog: code == PrayerLogErrorCode.alreadyLogged
          ? _existingLog(e.data)
          : null,
      nextPrayer: code == PrayerLogErrorCode.noActiveWindow
          ? _prayer(e.data?['nextPrayer'])
          : null,
      nextStartsAt: code == PrayerLogErrorCode.noActiveWindow
          ? DateTime.tryParse('${e.data?['startsAt']}')
          : null,
    );
  }

  /// The 409 carries the existing log, either as `data` itself or nested.
  static PrayerLog? _existingLog(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data['id'] != null ? data : data['log'] ?? data['existing'];
    if (raw is! Map<String, dynamic>) return null;
    try {
      return prayerLogFromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static PrayerName? _prayer(Object? raw) {
    for (final p in PrayerName.values) {
      if (p.name == raw) return p;
    }
    return null;
  }
}
