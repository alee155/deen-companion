import '../../../../core/usecase/usecase.dart';
import '../entities/daily_content.dart';

abstract class DailyContentRepository {
  /// Content already on the device for [dateKey]; never touches the network.
  DailyContent? getCached(String dateKey);

  /// Cache-first: only goes to the network for a day not seen before.
  Future<Result<DailyContent>> fetch(String dateKey);

  /// Drops cached content for days before [dateKey].
  Future<void> pruneBefore(String dateKey);
}
