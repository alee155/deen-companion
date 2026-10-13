import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/group_model.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class GroupsRemoteDataSource {
  Future<List<GroupModel>> getGroups();

  /// [description] is optional on the backend; null/empty is omitted.
  Future<GroupModel> createGroup({required String name, String? description});

  Future<GroupDetailModel> getGroupDetail(String groupId);

  /// `PATCH /groups/{id}`; the response has no members/role.
  Future<GroupModel> updateGroup(
    String groupId, {
    required String name,
    required String description,
  });

  Future<void> deleteGroup(String groupId);

  Future<GroupInviteModel> getInvite(String groupId);

  /// Invalidates the old link and returns the new one.
  Future<GroupInviteModel> resetInvite(String groupId);

  /// Admin only. `DELETE /groups/{id}/members/{userId}`.
  Future<void> removeMember(String groupId, String userId);

  /// `POST /groups/{id}/leave` — if the admin leaves, the next member is
  /// promoted; if the last member leaves, the group is deleted.
  Future<void> leaveGroup(String groupId);

  /// `GET /invites/{token}` — public; richer when authenticated.
  Future<InvitePreviewModel> getInvitePreview(String token);

  /// `POST /invites/{token}/join` — requires login.
  Future<JoinResultModel> joinWithInvite(String token);
}

class GroupsRemoteDataSourceImpl implements GroupsRemoteDataSource {
  final Dio dio;
  const GroupsRemoteDataSourceImpl(this.dio);

  @override
  Future<List<GroupModel>> getGroups() => _data(
    () => dio.get(ApiEndpoints.groups),
    (data) => [
      for (final g in data as List)
        GroupModel.fromJson(g as Map<String, dynamic>),
    ],
  );

  @override
  Future<GroupModel> createGroup({required String name, String? description}) =>
      _data(
        () => dio.post(
          ApiEndpoints.groups,
          data: {
            'name': name,
            if (description != null && description.isNotEmpty)
              'description': description,
          },
        ),
        (data) => GroupModel.fromJson(data as Map<String, dynamic>),
      );

  @override
  Future<GroupDetailModel> getGroupDetail(String groupId) => _data(
    () => dio.get(ApiEndpoints.group(groupId)),
    (data) => GroupDetailModel.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<GroupModel> updateGroup(
    String groupId, {
    required String name,
    required String description,
  }) => _data(
    () => dio.patch(
      ApiEndpoints.group(groupId),
      data: {'name': name, 'description': description},
    ),
    (data) => GroupModel.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<void> deleteGroup(String groupId) =>
      _data(() => dio.delete(ApiEndpoints.group(groupId)), (_) {});

  @override
  Future<GroupInviteModel> getInvite(String groupId) => _data(
    () => dio.get(ApiEndpoints.groupInvite(groupId)),
    (data) => GroupInviteModel.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<GroupInviteModel> resetInvite(String groupId) => _data(
    () => dio.post(ApiEndpoints.groupInviteReset(groupId)),
    (data) => GroupInviteModel.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<void> removeMember(String groupId, String userId) => _data(
    () => dio.delete(ApiEndpoints.groupMember(groupId, userId)),
    (_) {},
  );

  @override
  Future<void> leaveGroup(String groupId) =>
      _data(() => dio.post(ApiEndpoints.groupLeave(groupId)), (_) {});

  @override
  Future<InvitePreviewModel> getInvitePreview(String token) => _data(
    () => dio.get(ApiEndpoints.invitePreview(token)),
    (data) => InvitePreviewModel.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<JoinResultModel> joinWithInvite(String token) => _data(
    () => dio.post(ApiEndpoints.inviteJoin(token)),
    (data) => JoinResultModel.fromJson(data as Map<String, dynamic>),
  );

  Future<T> _data<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Object? data) parse,
  ) async {
    try {
      final body = (await call()).data as Map<String, dynamic>;
      if (body['success'] != true) throw const ServerException();
      return parse(body['data']);
    } on DioException catch (e) {
      throw mapDioException(e);
    } on TypeError {
      throw const ServerException();
    }
  }
}
