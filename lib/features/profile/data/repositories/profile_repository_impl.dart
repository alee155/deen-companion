import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/flow_log.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/domain/entities/gender.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

const _tag = 'PROFILE';

/// The longest name the server accepts.
const maxProfileNameLength = 255;

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource remote;
  const ProfileRepositoryImpl(this.remote);

  @override
  Future<Result<UserProfile>> getProfile() => _guard(
    'getProfile',
    remote.getProfile,
    (p) => 'PROFILE RECEIVED: ${p.avatarUrl == null ? 'no' : 'has'} picture',
  );

  @override
  Future<Result<UserProfile>> updateProfile({String? name, String? imagePath}) {
    final trimmed = name?.trim();
    // Never send what the server will refuse.
    if ((trimmed == null || trimmed.isEmpty) && imagePath == null) {
      return Future.value(
        const Error(ServerFailure('Enter a name or choose a new photo.')),
      );
    }
    if (trimmed != null && trimmed.length > maxProfileNameLength) {
      return Future.value(
        const Error(
          ServerFailure(
            'Name can be at most $maxProfileNameLength characters.',
          ),
        ),
      );
    }
    return _guard(
      'updateProfile',
      () => remote.updateProfile(
        name: trimmed == null || trimmed.isEmpty ? null : trimmed,
        imagePath: imagePath,
      ),
      (p) => 'PROFILE SAVED',
    );
  }

  @override
  Future<Result<UserProfile>> removeAvatar() =>
      _guard('removeAvatar', remote.removeAvatar, (_) => 'PICTURE REMOVED');

  @override
  Future<Result<UserPoints>> getPoints() => _guard(
    'getPoints',
    remote.getPoints,
    (p) => 'POINTS RECEIVED: ${p.total} across ${p.groups.length} groups',
  );

  @override
  Future<Result<void>> setGender(Gender gender) =>
      _guard('setGender', () => remote.setGender(gender), (_) => 'GENDER SET');

  @override
  Future<Result<void>> setTimezone(String timezone) => _guard(
    'setTimezone',
    () => remote.setTimezone(timezone),
    (_) => 'TIMEZONE SET: $timezone',
  );

  Future<Result<T>> _guard<T>(
    String op,
    Future<T> Function() body,
    String Function(T) describe,
  ) async {
    try {
      final data = await body();
      FlowLog.log(_tag, describe(data));
      return Success(data);
    } on NetworkException {
      FlowLog.error(_tag, '$op: NO CONNECTION');
      return const Error(NetworkFailure());
    } on NotFoundException {
      return const Error(NotFoundFailure());
    } on ServerException catch (e) {
      FlowLog.error(_tag, '$op: SERVER ERROR', '${e.statusCode} ${e.message}');
      if (e.code == 'GENDER_ALREADY_SET') {
        return const Error(GenderAlreadySet());
      }
      if (e.statusCode == 413) {
        return const Error(
          ServerFailure('That photo is too large. Choose a smaller one.'),
        );
      }
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('ProfileRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
