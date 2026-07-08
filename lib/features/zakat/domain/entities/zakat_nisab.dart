class ZakatNisabAsset {
  final int thresholdGrams;
  final double? monetaryValue;
  final String note;
  const ZakatNisabAsset({
    required this.thresholdGrams,
    this.monetaryValue,
    required this.note,
  });
}

class ZakatNisab {
  final ZakatNisabAsset gold;
  final ZakatNisabAsset silver;
  final String note;
  final String zakatRate;
  const ZakatNisab({
    required this.gold,
    required this.silver,
    required this.note,
    required this.zakatRate,
  });
}
