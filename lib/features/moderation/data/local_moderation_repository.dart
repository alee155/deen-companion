import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failures.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/flow_log.dart';
import '../domain/entities/blocked_user.dart';
import '../domain/entities/report_reason.dart';
import '../domain/entities/report_target.dart';
import '../domain/repositories/moderation_repository.dart';

/// STAND-IN until the backend has report and block endpoints.
///
///  * **Blocking** is real on this device: the list is saved per account and
///    the screens hide blocked people's snaps. It isn't sent to the server, so
///    it doesn't follow the user to another phone.
///  * **Reporting** is accepted and logged, but **not sent anywhere**. Nobody
///    reviews it. This must be replaced by the API before the app is released
///    to the public (App Store and Play Store both expect reports to reach a
///    person).
class LocalModerationRepository implements ModerationRepository {
  final LocalStorageService storage;

  /// The signed-in user's id; each account keeps its own blocked list. Null for
  /// a guest (who has none).
  final String? ownerId;

  const LocalModerationRepository({
    required this.storage,
    required this.ownerId,
  });

  String get _key => '${AppConstants.blockedUsersKey}:${ownerId ?? 'guest'}';

  @override
  Future<Result<void>> report({
    required ReportTarget target,
    required ReportReason reason,
    String? details,
  }) async {
    FlowLog.log(
      'REPORT',
      'NOT SENT ANYWHERE (no API yet): ${target.runtimeType} '
          'reason=${reason.apiValue} hasDetails=${(details ?? '').trim().isNotEmpty}',
    );
    // Long enough to see the sending state, short enough not to be a wait.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const Success(null);
  }

  @override
  Future<Result<List<BlockedUser>>> getBlockedUsers() async {
    try {
      return Success(_read());
    } catch (_) {
      return const Error(CacheFailure('Couldn’t load your blocked users.'));
    }
  }

  @override
  Future<Result<void>> blockUser(BlockedUser user) async {
    try {
      final all = _read().where((b) => b.userId != user.userId).toList();
      await _write([user, ...all]);
      return const Success(null);
    } catch (_) {
      return const Error(
        CacheFailure('Couldn’t block this person. Try again.'),
      );
    }
  }

  @override
  Future<Result<void>> unblockUser(String userId) async {
    try {
      await _write(_read().where((b) => b.userId != userId).toList());
      return const Success(null);
    } catch (_) {
      return const Error(
        CacheFailure('Couldn’t unblock this person. Try again.'),
      );
    }
  }

  List<BlockedUser> _read() {
    final raw = storage.get<String>(AppConstants.settingsBoxName, _key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (BlockedUser.fromJson(item) case final b?) b,
    ];
  }

  Future<void> _write(List<BlockedUser> users) => storage.put(
    AppConstants.settingsBoxName,
    _key,
    jsonEncode([for (final u in users) u.toJson()]),
  );
}
