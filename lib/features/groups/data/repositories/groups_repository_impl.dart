import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_detail.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/entities/invite_preview.dart';
import '../../domain/repositories/groups_repository.dart';
import '../datasources/groups_remote_datasource.dart';

class GroupsRepositoryImpl implements GroupsRepository {
  final GroupsRemoteDataSource remote;

  const GroupsRepositoryImpl({required this.remote});

  @override
  Future<Result<List<Group>>> getMyGroups() => _guard(
    'getMyGroups',
    () async => [for (final m in await remote.getGroups()) m.toEntity()],
  );

  @override
  Future<Result<Group>> createGroup(NewGroup input) =>
      _guard('createGroup', () async {
        final model = await remote.createGroup(
          name: input.name,
          description: input.description,
          imagePath: input.imagePath,
        );
        // POST /groups omits `role`; whoever creates a group administers it.
        return model.toEntity(fallbackRole: GroupRole.admin);
      });

  @override
  Future<Result<GroupDetail>> getGroupDetail(String groupId) => _guard(
    'getGroupDetail',
    () async => (await remote.getGroupDetail(groupId)).toEntity(),
  );

  @override
  Future<Result<Group>> updateGroup(
    String groupId, {
    required String name,
    required String description,
    String? imagePath,
  }) => _guard('updateGroup', () async {
    final model = await remote.updateGroup(
      groupId,
      name: name,
      description: description,
      imagePath: imagePath,
    );
    // PATCH omits `role`; only admins can edit, so it is admin.
    return model.toEntity(fallbackRole: GroupRole.admin);
  });

  @override
  Future<Result<void>> removeGroupImage(String groupId) =>
      _guard('removeGroupImage', () => remote.removeAvatar(groupId));

  @override
  Future<Result<void>> deleteGroup(String groupId) =>
      _guard('deleteGroup', () => remote.deleteGroup(groupId));

  @override
  Future<Result<GroupInvite>> getInvite(String groupId) => _guard(
    'getInvite',
    () async => (await remote.getInvite(groupId)).toEntity(),
  );

  @override
  Future<Result<GroupInvite>> resetInvite(String groupId) => _guard(
    'resetInvite',
    () async => (await remote.resetInvite(groupId)).toEntity(),
  );

  @override
  Future<Result<void>> removeMember(String groupId, String userId) =>
      _guard('removeMember', () => remote.removeMember(groupId, userId));

  @override
  Future<Result<void>> leaveGroup(String groupId) =>
      _guard('leaveGroup', () => remote.leaveGroup(groupId));

  @override
  Future<Result<InvitePreview>> previewInvite(String token) => _guard(
    'previewInvite',
    () async => (await remote.getInvitePreview(token)).toEntity(),
  );

  @override
  Future<Result<JoinResult>> joinGroup(String token) => _guard(
    'joinGroup',
    () async => (await remote.joinWithInvite(token)).toEntity(),
  );

  Future<Result<T>> _guard<T>(String op, Future<T> Function() body) async {
    try {
      return Success(await body());
    } on NetworkException {
      return const Error(NetworkFailure());
    } on NotFoundException {
      return const Error(NotFoundFailure());
    } on ServerException catch (e) {
      if (e.statusCode == 413) {
        return const Error(
          ServerFailure('That photo is too large. Choose a smaller one.'),
        );
      }
      final m = e.message;
      return Error(m == null ? const ServerFailure() : ServerFailure(m));
    } catch (e, st) {
      AppLogger.e('GroupsRepository: $op failed', e, st);
      return const Error(UnexpectedFailure());
    }
  }
}
