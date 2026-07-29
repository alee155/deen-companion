import '../../../../core/cache/hive_cache_store.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/zakat_calculation.dart';
import '../../domain/entities/zakat_info.dart';
import '../../domain/entities/zakat_nisab.dart';
import '../../domain/repositories/zakat_repository.dart';
import '../datasources/zakat_remote_datasource.dart';
import '../models/zakat_calculation_model.dart';
import '../models/zakat_info_model.dart';

class ZakatRepositoryImpl implements ZakatRepository {
  final ZakatRemoteDataSource remoteDataSource;
  final HiveCacheStore cacheStore;
  final NetworkInfo networkInfo;

  const ZakatRepositoryImpl({
    required this.remoteDataSource,
    required this.cacheStore,
    required this.networkInfo,
  });

  static const _infoCacheKey = 'zakat_info';
  static const _infoCacheTtl = Duration(days: 90); // static educational content

  @override
  ZakatInfo? getCachedInfo() {
    return cacheStore
        .read(_infoCacheKey, ZakatInfoModel.fromJson)
        ?.data
        .toEntity();
  }

  @override
  Future<Result<ZakatInfo>> fetchAndCacheInfo({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cacheStore.read(_infoCacheKey, ZakatInfoModel.fromJson);
      if (cached != null && !cached.isStale(_infoCacheTtl))
        return Success(cached.data.toEntity());
    }

    if (!await networkInfo.isConnected) {
      final cached = getCachedInfo();
      if (cached != null) return Success(cached);
      return const Error(NetworkFailure());
    }

    try {
      final model = await remoteDataSource.getInfo();
      await cacheStore.save(_infoCacheKey, model, (m) => m.toJson());
      return Success(model.toEntity());
    } on ServerException catch (e) {
      final cached = getCachedInfo();
      if (cached != null) return Success(cached);
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('ZakatRepository: unexpected error (info)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<ZakatNisab>> fetchNisab({
    double? goldPricePerGram,
    double? silverPricePerGram,
  }) async {
    if (!await networkInfo.isConnected) return const Error(NetworkFailure());

    try {
      final model = await remoteDataSource.getNisab(
        goldPricePerGram: goldPricePerGram,
        silverPricePerGram: silverPricePerGram,
      );
      return Success(model.toEntity());
    } on ServerException catch (e) {
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e('ZakatRepository: unexpected error (nisab)', e, stackTrace);
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<ZakatCalculationResult>> calculate(
    ZakatCalculationInput input,
  ) async {
    if (!await networkInfo.isConnected) return const Error(NetworkFailure());

    try {
      final request = ZakatCalculateRequestModel(
        goldPricePerGram: input.goldPricePerGram,
        silverPricePerGram: input.silverPricePerGram,
        nisabStandard: input.nisabStandard == NisabStandard.silver
            ? 'silver'
            : 'gold',
        cash: input.includeCash ? input.cash : 0,
        goldGrams: input.includeGold ? input.goldGrams : 0,
        silverGrams: input.includeSilver ? input.silverGrams : 0,
        stocks: input.includeStocks ? input.stocks : 0,
        businessGoods: input.includeBusinessGoods ? input.businessGoods : 0,
        otherInvestments: input.includeOtherInvestments
            ? input.otherInvestments
            : 0,
        liabilities: input.includeLiabilities ? input.liabilities : 0,
      );
      final response = await remoteDataSource.calculate(request);
      return Success(response.toEntity());
    } on ServerException catch (e) {
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'ZakatRepository: unexpected error (calculate)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }

  @override
  Future<Result<AgricultureZakatResult>> calculateAgriculture(
    double value,
    WaterSource waterSource,
  ) async {
    if (!await networkInfo.isConnected) return const Error(NetworkFailure());

    try {
      final request = ZakatAgricultureRequestModel(
        value: value,
        waterSource: waterSource == WaterSource.irrigation
            ? 'irrigation'
            : 'rain',
      );
      final response = await remoteDataSource.calculateAgriculture(request);
      return Success(response.toEntity());
    } on ServerException catch (e) {
      return Error(
        ServerFailure(
          e.message ?? 'Something went wrong on our end. Try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.e(
        'ZakatRepository: unexpected error (agriculture)',
        e,
        stackTrace,
      );
      return const Error(UnexpectedFailure());
    }
  }
}
