import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../models/group_model.dart';

/// The Bearer token is attached by the Dio `AuthInterceptor`.
abstract class GroupsRemoteDataSource {
  Future<List<GroupModel>> getGroups();

  /// [description] is optional on the backend; null/empty is omitted. A
  /// non-null [imagePath] is uploaded as the group picture.
  Future<GroupModel> createGroup({
    required String name,
    String? description,
    String? imagePath,
  });

  Future<GroupDetailModel> getGroupDetail(String groupId);

  /// `PATCH /groups/{id}`; the response has no members/role. A non-null
  /// [imagePath] replaces the picture.
  Future<GroupModel> updateGroup(
    String groupId, {
    required String name,
    required String description,
    String? imagePath,
  });

  /// `DELETE /groups/{id}/avatar` — admin only.
  Future<void> removeAvatar(String groupId);

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
  Future<GroupModel> createGroup({
    required String name,
    String? description,
    String? imagePath,
  }) => _data(
    () async => dio.post(
      ApiEndpoints.groups,
      // Multipart, with `file` only when there is a picture: an empty file
      // part is not a picture.
      data: FormData.fromMap({
        'name': name,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imagePath != null) 'file': await _file(imagePath),
      }),
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
    String? imagePath,
  }) => _data(
    () async => dio.patch(
      ApiEndpoints.group(groupId),
      // A picture needs multipart; without one a JSON body works.
      data: imagePath == null
          ? {'name': name, 'description': description}
          : FormData.fromMap({
              'name': name,
              'description': description,
              'file': await _file(imagePath),
            }),
    ),
    (data) => GroupModel.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<void> removeAvatar(String groupId) =>
      _data(() => dio.delete(ApiEndpoints.groupAvatar(groupId)), (_) {});

  static Future<MultipartFile> _file(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '.jpg' : path.substring(dot).toLowerCase();
    return MultipartFile.fromFile(
      path,
      filename: 'group$ext',
      // The server accepts JPEG, PNG and WebP only.
      contentType: switch (ext) {
        '.png' => DioMediaType('image', 'png'),
        '.webp' => DioMediaType('image', 'webp'),
        _ => DioMediaType('image', 'jpeg'),
      },
    );
  }

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
