import '../../../../core/usecase/usecase.dart';
import '../entities/zakat_calculation.dart';
import '../entities/zakat_info.dart';
import '../entities/zakat_nisab.dart';

abstract class ZakatRepository {
  ZakatInfo? getCachedInfo();
  Future<Result<ZakatInfo>> fetchAndCacheInfo({bool forceRefresh = false});

  Future<Result<ZakatNisab>> fetchNisab({
    double? goldPricePerGram,
    double? silverPricePerGram,
  });

  Future<Result<ZakatCalculationResult>> calculate(ZakatCalculationInput input);
  Future<Result<AgricultureZakatResult>> calculateAgriculture(
    double value,
    WaterSource waterSource,
  );
}
