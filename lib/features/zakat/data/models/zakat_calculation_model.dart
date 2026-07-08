import '../../domain/entities/zakat_calculation.dart';

class ZakatCalculateRequestModel {
  final double? goldPricePerGram;
  final double? silverPricePerGram;
  final String nisabStandard;
  final double cash;
  final double goldGrams;
  final double silverGrams;
  final double stocks;
  final double businessGoods;
  final double otherInvestments;
  final double liabilities;

  const ZakatCalculateRequestModel({
    this.goldPricePerGram,
    this.silverPricePerGram,
    required this.nisabStandard,
    required this.cash,
    required this.goldGrams,
    required this.silverGrams,
    required this.stocks,
    required this.businessGoods,
    required this.otherInvestments,
    required this.liabilities,
  });

  Map<String, dynamic> toJson() => {
    if (goldPricePerGram != null) 'gold_price_per_gram': goldPricePerGram,
    if (silverPricePerGram != null) 'silver_price_per_gram': silverPricePerGram,
    'nisab_standard': nisabStandard,
    'cash': cash,
    'gold_grams': goldGrams,
    'silver_grams': silverGrams,
    'stocks': stocks,
    'business_goods': businessGoods,
    'other_investments': otherInvestments,
    'liabilities': liabilities,
  };
}

class ZakatBreakdownModel {
  final double cash;
  final double goldValue;
  final double silverValue;
  final double stocks;
  final double businessGoods;
  final double otherInvestments;
  final double grossWealth;
  final double liabilities;
  final double netZakatableWealth;

  const ZakatBreakdownModel({
    required this.cash,
    required this.goldValue,
    required this.silverValue,
    required this.stocks,
    required this.businessGoods,
    required this.otherInvestments,
    required this.grossWealth,
    required this.liabilities,
    required this.netZakatableWealth,
  });

  factory ZakatBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ZakatBreakdownModel(
      cash: (json['cash'] as num).toDouble(),
      goldValue: (json['gold_value'] as num).toDouble(),
      silverValue: (json['silver_value'] as num).toDouble(),
      stocks: (json['stocks'] as num).toDouble(),
      businessGoods: (json['business_goods'] as num).toDouble(),
      otherInvestments: (json['other_investments'] as num).toDouble(),
      grossWealth: (json['gross_wealth'] as num).toDouble(),
      liabilities: (json['liabilities'] as num).toDouble(),
      netZakatableWealth: (json['net_zakatable_wealth'] as num).toDouble(),
    );
  }

  ZakatBreakdown toEntity() => ZakatBreakdown(
    cash: cash,
    goldValue: goldValue,
    silverValue: silverValue,
    stocks: stocks,
    businessGoods: businessGoods,
    otherInvestments: otherInvestments,
    grossWealth: grossWealth,
    liabilities: liabilities,
    netZakatableWealth: netZakatableWealth,
  );
}

class ZakatCalculateResponseModel {
  final double zakatDue;
  final bool aboveNisab;
  final String nisabStandard;
  final double nisabValue;
  final int nisabGoldGrams;
  final int nisabSilverGrams;
  final String rate;
  final ZakatBreakdownModel breakdown;
  final String note;

  const ZakatCalculateResponseModel({
    required this.zakatDue,
    required this.aboveNisab,
    required this.nisabStandard,
    required this.nisabValue,
    required this.nisabGoldGrams,
    required this.nisabSilverGrams,
    required this.rate,
    required this.breakdown,
    required this.note,
  });

  factory ZakatCalculateResponseModel.fromJson(Map<String, dynamic> json) {
    return ZakatCalculateResponseModel(
      zakatDue: (json['zakat_due'] as num).toDouble(),
      aboveNisab: json['above_nisab'] as bool,
      nisabStandard: json['nisab_standard'] as String,
      nisabValue: (json['nisab_value'] as num).toDouble(),
      nisabGoldGrams: json['nisab_gold_grams'] as int,
      nisabSilverGrams: json['nisab_silver_grams'] as int,
      rate: json['rate'] as String,
      breakdown: ZakatBreakdownModel.fromJson(
        json['breakdown'] as Map<String, dynamic>,
      ),
      note: json['note'] as String,
    );
  }

  ZakatCalculationResult toEntity() => ZakatCalculationResult(
    zakatDue: zakatDue,
    aboveNisab: aboveNisab,
    nisabStandard: nisabStandard == 'silver'
        ? NisabStandard.silver
        : NisabStandard.gold,
    nisabValue: nisabValue,
    nisabGoldGrams: nisabGoldGrams,
    nisabSilverGrams: nisabSilverGrams,
    rate: rate,
    breakdown: breakdown.toEntity(),
    note: note,
  );
}

class ZakatAgricultureRequestModel {
  final double value;
  final String waterSource; // 'rain' | 'irrigation'

  const ZakatAgricultureRequestModel({
    required this.value,
    required this.waterSource,
  });

  Map<String, dynamic> toJson() => {
    'value': value,
    'water_source': waterSource,
  };
}

class ZakatAgricultureResponseModel {
  final double value;
  final String waterSource;
  final String rate;
  final double zakatDue;
  final String note;

  const ZakatAgricultureResponseModel({
    required this.value,
    required this.waterSource,
    required this.rate,
    required this.zakatDue,
    required this.note,
  });

  factory ZakatAgricultureResponseModel.fromJson(Map<String, dynamic> json) {
    return ZakatAgricultureResponseModel(
      value: (json['value'] as num).toDouble(),
      waterSource: json['water_source'] as String,
      rate: json['rate'] as String,
      zakatDue: (json['zakat_due'] as num).toDouble(),
      note: json['note'] as String,
    );
  }

  AgricultureZakatResult toEntity() => AgricultureZakatResult(
    value: value,
    waterSource: waterSource == 'irrigation'
        ? WaterSource.irrigation
        : WaterSource.rain,
    rate: rate,
    zakatDue: zakatDue,
    note: note,
  );
}
