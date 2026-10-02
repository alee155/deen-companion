import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../../hadith/data/models/hadith_model.dart';
import '../../domain/daily_content_selector.dart';
import '../../domain/entities/daily_content.dart';
import '../../domain/repositories/daily_content_repository.dart';
import '../daily_content_remote_source.dart';
import '../daily_content_store.dart';

class DailyContentRepositoryImpl implements DailyContentRepository {
  final DailyContentRemoteSource remote;
  final DailyContentStore store;
  final NetworkInfo networkInfo;

  const DailyContentRepositoryImpl({
    required this.remote,
    required this.store,
    required this.networkInfo,
  });

  @override
  DailyContent? getCached(String dateKey) => store.readContent(dateKey);

  @override
  Future<Result<DailyContent>> fetch(String dateKey) async {
    final cached = store.readContent(dateKey);
    if (cached != null) return Success(cached);

    final date = DailyContentSelector.parseDateKey(dateKey);
    if (date == null) return const Error(UnexpectedFailure());
    if (!await networkInfo.isConnected) return const Error(NetworkFailure());

    try {
      final (surah, ayahNumber) = DailyContentSelector.ayahFor(date);
      final results = await Future.wait([
        remote.getAyah(surah, ayahNumber),
        remote.getHadith(
          DailyContentSelector.hadithCollection,
          DailyContentSelector.hadithNumberFor(date),
        ),
      ]);
      final ayah = results[0] as DailyAyah;
      final hadithModel = results[1] as HadithModel;
      await store.writeContent(dateKey, ayah, hadithModel);
      return Success(
        DailyContent(
          dateKey: dateKey,
          ayah: ayah,
          hadith: hadithModel.toEntity(),
        ),
      );
    } on ServerException catch (e) {
      return Error(
        ServerFailure(e.message ?? 'Something went wrong on our end.'),
      );
    } catch (e, st) {
      AppLogger.e('DailyContentRepository: unexpected error', e, st);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<void> pruneBefore(String dateKey) => store.pruneContentBefore(dateKey);
}
