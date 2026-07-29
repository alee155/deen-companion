class ZakatNisabInfo {
  final int grams;
  final String description;
  const ZakatNisabInfo({required this.grams, required this.description});
}

class ZakatInfo {
  final String definition;
  final ZakatNisabInfo nisabGold;
  final ZakatNisabInfo nisabSilver;
  final String nisabNote;
  final String rateGeneral;
  final String rateAgricultureRain;
  final String rateAgricultureIrrigated;
  final List<String> conditions;
  final List<String> eligibleRecipients;
  final List<String> zakatableAssets;
  final List<String> nonZakatableAssets;
  final String hawl;
  final String disclaimer;
  final String source;

  const ZakatInfo({
    required this.definition,
    required this.nisabGold,
    required this.nisabSilver,
    required this.nisabNote,
    required this.rateGeneral,
    required this.rateAgricultureRain,
    required this.rateAgricultureIrrigated,
    required this.conditions,
    required this.eligibleRecipients,
    required this.zakatableAssets,
    required this.nonZakatableAssets,
    required this.hawl,
    required this.disclaimer,
    required this.source,
  });
}
