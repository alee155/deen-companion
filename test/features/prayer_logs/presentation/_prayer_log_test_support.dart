import 'package:deen_companion/core/error/failures.dart';
import 'package:deen_companion/core/usecase/usecase.dart';
import 'package:deen_companion/features/auth/domain/entities/auth_session.dart';
import 'package:deen_companion/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:deen_companion/features/prayer_logs/domain/current_prayer.dart';
import 'package:deen_companion/features/prayer_logs/domain/group_member_prayers.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_log.dart';
import 'package:deen_companion/features/prayer_logs/domain/prayer_logs_repository.dart';
import 'package:deen_companion/features/prayer_logs/presentation/providers/prayer_logs_providers.dart';
import 'package:deen_companion/features/prayer_times/domain/entities/prayer_times.dart';

class SignedIn extends AuthSessionNotifier {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'me', email: 'me@b.c', name: 'Me');
}

class SignedOut extends AuthSessionNotifier {
  @override
  AuthSession build() => const AuthSession.guest();
}

/// Home state fixed by the test; refresh is a no-op.
class FixedCurrent extends CurrentPrayerNotifier {
  final CurrentPrayerState value;
  int refreshes = 0;
  FixedCurrent(this.value);

  @override
  Future<CurrentPrayerState> build() async => value;

  @override
  Future<void> refresh() async => refreshes++;
}

PrayerLog logOf(
  PrayerName prayer, {
  String? snapUrl,
  int points = 5,
  DateTime? endsAt,
  String id = 'log-1',
}) => PrayerLog(
  id: id,
  prayer: prayer,
  date: '2026-10-13',
  status: PrayerLogStatus.onTime,
  points: points,
  snapUrl: snapUrl,
  windowStartsAt: DateTime.now().subtract(const Duration(hours: 1)),
  windowEndsAt: endsAt ?? DateTime.now().add(const Duration(hours: 1)),
  loggedAt: DateTime.now(),
);

CurrentPrayerState openState({bool logged = false, String? logId}) =>
    CurrentPrayerState(
      now: DateTime.now(),
      current: CurrentPrayer(
        prayer: PrayerName.asr,
        date: '2026-10-13',
        startsAt: DateTime.now().subtract(const Duration(minutes: 30)),
        endsAt: DateTime.now().add(const Duration(hours: 1, minutes: 55)),
        logged: logged,
        logId: logId,
      ),
      next: NextPrayer(
        prayer: PrayerName.maghrib,
        startsAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    );

/// Repository whose results the test sets.
class ScriptedLogsRepo implements PrayerLogsRepository {
  Result<PrayerLog> logResult = const Error(NetworkFailure());
  Result<void> deleteResult = const Success(null);
  Result<OpenedSnap> viewResult = const Error(NetworkFailure());
  final List<String> viewed = [];
  Result<List<GroupMemberPrayers>> feedResult = const Success([]);
  final List<String> logged = [];
  final List<String> deleted = [];
  int currentCalls = 0;
  CurrentPrayerState current = CurrentPrayerState(now: DateTime.now());

  @override
  Future<Result<PrayerLog>> logPrayer(
    String imagePath, {
    int? viewSeconds,
    List<String>? groupIds,
  }) async {
    logged.add(imagePath);
    return logResult;
  }

  Result<PrayerLog> addResult = const Error(NetworkFailure());
  final List<(String, List<String>)> added = [];

  @override
  Future<Result<PrayerLog>> addSnapGroups(
    String logId,
    List<String> groupIds,
  ) async {
    added.add((logId, groupIds));
    return addResult;
  }

  @override
  Future<Result<OpenedSnap>> viewSnap(String logId) async {
    viewed.add(logId);
    return viewResult;
  }

  @override
  Future<Result<void>> deleteLog(String id) async {
    deleted.add(id);
    return deleteResult;
  }

  @override
  Future<Result<List<GroupMemberPrayers>>> getGroupPrayers(
    String groupId, {
    String? date,
  }) async => feedResult;

  @override
  Future<Result<CurrentPrayerState>> getCurrent() async {
    currentCalls++;
    return Success(current);
  }

  @override
  Future<Result<List<PrayerLog>>> getLogs({String? date}) async =>
      const Success([]);

  @override
  Future<Result<List<PrayerLog>>> getLogsRange({
    required String from,
    required String to,
  }) async => const Success([]);
}
