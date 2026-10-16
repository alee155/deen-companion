import '../../../../core/usecase/usecase.dart';
import '../entities/snap_draft.dart';

abstract class SnapRepository {
  /// Sends [draft]. In the app this is `POST /prayers/logs` (see
  /// `PrayerLogSnapRepository`); [MockSnapRepository] is a simulation kept for
  /// previews and tests.
  Future<Result<SentSnap>> sendSnap(SnapDraft draft);
}
