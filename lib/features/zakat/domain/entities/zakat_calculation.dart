enum NisabStandard { gold, silver }

enum WaterSource { rain, irrigation }

class ZakatCalculationInput {
  final double? goldPricePerGram;
  final double? silverPricePerGram;
  final NisabStandard nisabStandard;
  final bool includeCash;
  final double cash;
  final bool includeGold;
  final double goldGrams;
  final bool includeSilver;
  final double silverGrams;
  final bool includeStocks;
  final double stocks;
  final bool includeBusinessGoods;
  final double businessGoods;
  final bool includeOtherInvestments;
  final double otherInvestments;
  final bool includeLiabilities;
  final double liabilities;

  const ZakatCalculationInput({
    this.goldPricePerGram,
    this.silverPricePerGram,
    this.nisabStandard = NisabStandard.gold,
    this.includeCash = false,
    this.cash = 0,
    this.includeGold = false,
    this.goldGrams = 0,
    this.includeSilver = false,
    this.silverGrams = 0,
    this.includeStocks = false,
    this.stocks = 0,
    this.includeBusinessGoods = false,
    this.businessGoods = 0,
    this.includeOtherInvestments = false,
    this.otherInvestments = 0,
    this.includeLiabilities = false,
    this.liabilities = 0,
  });
}

class ZakatBreakdown {
  final double cash;
  final double goldValue;
  final double silverValue;
  final double stocks;
  final double businessGoods;
  final double otherInvestments;
  final double grossWealth;
  final double liabilities;
  final double netZakatableWealth;

  const ZakatBreakdown({
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
}

class ZakatCalculationResult {
  final double zakatDue;
  final bool aboveNisab;
  final NisabStandard nisabStandard;
  final double nisabValue;
  final int nisabGoldGrams;
  final int nisabSilverGrams;
  final String rate;
  final ZakatBreakdown breakdown;
  final String note;

  const ZakatCalculationResult({
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
}

class AgricultureZakatResult {
  final double value;
  final WaterSource waterSource;
  final String rate;
  final double zakatDue;
  final String note;

  const AgricultureZakatResult({
    required this.value,
    required this.waterSource,
    required this.rate,
    required this.zakatDue,
    required this.note,
  });
}
