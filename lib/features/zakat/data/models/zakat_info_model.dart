import '../../domain/entities/zakat_info.dart';

class ZakatNisabInfoModel {
  final int grams;
  final String description;
  const ZakatNisabInfoModel({required this.grams, required this.description});

  factory ZakatNisabInfoModel.fromJson(Map<String, dynamic> json) {
    return ZakatNisabInfoModel(
      grams: json['grams'] as int,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'grams': grams, 'description': description};
  ZakatNisabInfo toEntity() =>
      ZakatNisabInfo(grams: grams, description: description);
}

class ZakatInfoModel {
  final String definition;
  final ZakatNisabInfoModel nisabGold;
  final ZakatNisabInfoModel nisabSilver;
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

  const ZakatInfoModel({
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

  factory ZakatInfoModel.fromJson(Map<String, dynamic> json) {
    final nisab = json['nisab'] as Map<String, dynamic>;
    final rate = json['rate'] as Map<String, dynamic>;
    return ZakatInfoModel(
      definition: json['definition'] as String,
      nisabGold: ZakatNisabInfoModel.fromJson(
        nisab['gold'] as Map<String, dynamic>,
      ),
      nisabSilver: ZakatNisabInfoModel.fromJson(
        nisab['silver'] as Map<String, dynamic>,
      ),
      nisabNote: nisab['note'] as String,
      rateGeneral: rate['general'] as String,
      rateAgricultureRain: rate['agriculture_rain'] as String,
      rateAgricultureIrrigated: rate['agriculture_irrigated'] as String,
      conditions: List<String>.from(json['conditions'] as List),
      eligibleRecipients: List<String>.from(
        json['eligible_recipients'] as List,
      ),
      zakatableAssets: List<String>.from(json['zakatable_assets'] as List),
      nonZakatableAssets: List<String>.from(
        json['non_zakatable_assets'] as List,
      ),
      hawl: json['hawl'] as String,
      disclaimer: json['disclaimer'] as String,
      source: json['source'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'definition': definition,
    'nisab': {
      'gold': nisabGold.toJson(),
      'silver': nisabSilver.toJson(),
      'note': nisabNote,
    },
    'rate': {
      'general': rateGeneral,
      'agriculture_rain': rateAgricultureRain,
      'agriculture_irrigated': rateAgricultureIrrigated,
    },
    'conditions': conditions,
    'eligible_recipients': eligibleRecipients,
    'zakatable_assets': zakatableAssets,
    'non_zakatable_assets': nonZakatableAssets,
    'hawl': hawl,
    'disclaimer': disclaimer,
    'source': source,
  };

  ZakatInfo toEntity() => ZakatInfo(
    definition: definition,
    nisabGold: nisabGold.toEntity(),
    nisabSilver: nisabSilver.toEntity(),
    nisabNote: nisabNote,
    rateGeneral: rateGeneral,
    rateAgricultureRain: rateAgricultureRain,
    rateAgricultureIrrigated: rateAgricultureIrrigated,
    conditions: conditions,
    eligibleRecipients: eligibleRecipients,
    zakatableAssets: zakatableAssets,
    nonZakatableAssets: nonZakatableAssets,
    hawl: hawl,
    disclaimer: disclaimer,
    source: source,
  );
}
