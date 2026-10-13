import '../../../../core/usecase/usecase.dart';
import '../entities/snap_draft.dart';

abstract class SnapRepository {
  /// Uploads [draft] and delivers it to its recipients.
  ///
  /// TODO(snaps-backend): the POST API isn't ready. [MockSnapRepository]
  /// simulates it; swap the provider for a remote-backed implementation.
  Future<Result<SentSnap>> sendSnap(SnapDraft draft);
}
