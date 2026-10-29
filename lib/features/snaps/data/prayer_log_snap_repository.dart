import 'package:flutter/foundation.dart';
import '../../../core/error/failures.dart';
import '../../../core/usecase/usecase.dart';
import '../../prayer_logs/domain/prayer_log.dart';
import '../../prayer_logs/domain/prayer_log_failure.dart';
import '../../prayer_logs/presentation/prayer_labels.dart';
import '../domain/entities/snap_draft.dart';
import '../domain/repositories/snap_repository.dart';

/// Sending a snap is logging the prayer that is open right now, with the photo
/// as proof: `POST /prayers/logs` takes only the photo. The server decides
/// which prayer it is from its own clock. The draft's view timer goes along as
/// `viewDurationSeconds` and the chosen groups as `groupIds`, so the snap is
/// visible only in those. The caption is not part of that API yet, so it is
/// not sent.
///
/// [log] is the actual upload — `PrayerLogActions.log` in the app, which also
/// refreshes the screens that show prayer logs afterwards.
class PrayerLogSnapRepository implements SnapRepository {
  final Future<Result<PrayerLog>> Function(
    String imagePath, {
    int? viewSeconds,
    List<String>? groupIds,
  })
  log;
  const PrayerLogSnapRepository({required this.log});

  @override
  Future<Result<SentSnap>> sendSnap(SnapDraft draft) async {
    debugPrint(
      '^^^^^^^^^^^^^^^^^^^^ [GROUP PICK] CALLING POST /prayers/logs with '
      'groupIds ${draft.groupIds} (the snap is visible only in these)',
    );
    final result = await log(
      draft.imagePath,
      viewSeconds: draft.viewSeconds,
      groupIds: draft.groupIds,
    );
    return result.when(
      success: (l) => Success(SentSnap(id: l.id)),
      failure: (f) => Error(_forScreen(f)),
    );
  }

  /// The failure as the send screen should word it: a prayer-log error becomes
  /// a plain sentence ("No prayer is open right now. Dhuhr starts at …"), and
  /// everything else (offline, …) is passed through.
  static Failure _forScreen(Failure f) =>
      f is PrayerLogFailure ? ServerFailure(prayerLogErrorMessage(f)) : f;
}
