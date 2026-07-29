import '../../domain/entities/zakat_nisab.dart';

class ZakatNisabAssetModel {
  final int thresholdGrams;
  final double? monetaryValue;
  final String note;

  const ZakatNisabAssetModel({
    required this.thresholdGrams,
    this.monetaryValue,
    required this.note,
  });

  factory ZakatNisabAssetModel.fromJson(Map<String, dynamic> json) {
    return ZakatNisabAssetModel(
      thresholdGrams: json['threshold_grams'] as int,
      monetaryValue: (json['monetary_value'] as num?)?.toDouble(),
      note: json['note'] as String,
    );
  }

  ZakatNisabAsset toEntity() => ZakatNisabAsset(
    thresholdGrams: thresholdGrams,
    monetaryValue: monetaryValue,
    note: note,
  );
}

class ZakatNisabModel {
  final ZakatNisabAssetModel gold;
  final ZakatNisabAssetModel silver;
  final String note;
  final String zakatRate;

  const ZakatNisabModel({
    required this.gold,
    required this.silver,
    required this.note,
    required this.zakatRate,
  });

  factory ZakatNisabModel.fromJson(Map<String, dynamic> json) {
    return ZakatNisabModel(
      gold: ZakatNisabAssetModel.fromJson(json['gold'] as Map<String, dynamic>),
      silver: ZakatNisabAssetModel.fromJson(
        json['silver'] as Map<String, dynamic>,
      ),
      note: json['note'] as String,
      zakatRate: json['zakat_rate'] as String,
    );
  }

  ZakatNisab toEntity() => ZakatNisab(
    gold: gold.toEntity(),
    silver: silver.toEntity(),
    note: note,
    zakatRate: zakatRate,
  );
}
