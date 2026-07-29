/// AlAdhan calculation methods. Each region/authority defines its own Fajr
/// and Isha twilight angles, so the "right" method depends on where the
/// user actually is — there's no single correct default for the whole
/// world. IDs match https://api.aladhan.com/v1/methods (verify there if
/// AlAdhan ever renumbers something).
enum PrayerCalculationMethod {
  shiaIthnaAshari(0, 'Shia Ithna-Ashari, Leva Institute, Qum'),
  karachi(1, 'University of Islamic Sciences, Karachi'),
  isna(2, 'Islamic Society of North America (ISNA)'),
  muslimWorldLeague(3, 'Muslim World League'),
  ummAlQura(4, 'Umm Al-Qura University, Makkah'),
  egyptian(5, 'Egyptian General Authority of Survey'),
  tehran(7, 'Institute of Geophysics, University of Tehran'),
  gulfRegion(8, 'Gulf Region'),
  kuwait(9, 'Kuwait'),
  qatar(10, 'Qatar'),
  singapore(11, 'Majlis Ugama Islam Singapura'),
  franceUOIF(12, 'Union Organization Islamic de France'),
  turkeyDiyanet(13, 'Diyanet İşleri Başkanlığı, Turkey'),
  russia(14, 'Spiritual Administration of Muslims of Russia'),
  moonsightingCommittee(15, 'Moonsighting Committee Worldwide'),
  dubai(16, 'Dubai (experimental)'),
  jakimMalaysia(17, 'Jabatan Kemajuan Islam Malaysia (JAKIM)'),
  tunisia(18, 'Tunisia'),
  algeria(19, 'Algeria'),
  indonesiaKemenag(20, 'Kementerian Agama Republik Indonesia'),
  morocco(21, 'Morocco'),
  portugal(22, 'Comunidade Islamica de Lisboa (Portugal)'),
  jordan(23, 'Ministry of Awqaf, Jordan');

  final int id;
  final String label;
  const PrayerCalculationMethod(this.id, this.label);
}

/// Asr time depends on which juristic school is followed — Hanafi Asr
/// falls noticeably later than Shafi/Maliki/Hanbali. AlAdhan's `school`
/// query parameter: 0 = Shafi (and Maliki/Hanbali, same calculation), 1 =
/// Hanafi.
enum AsrSchool {
  shafi(0, 'Shafi, Maliki, Hanbali'),
  hanafi(1, 'Hanafi');

  final int id;
  final String label;
  const AsrSchool(this.id, this.label);
}

class PrayerCalculationSettings {
  final PrayerCalculationMethod method;
  final AsrSchool school;

  const PrayerCalculationSettings({required this.method, required this.school});

  /// Muslim World League is a widely-recognized, roughly region-neutral
  /// default — a meaningfully better starting point than hardcoding a
  /// North America-specific method for every user worldwide. Users should
  /// still pick the method their local mosque actually follows.
  static const fallback = PrayerCalculationSettings(
    method: PrayerCalculationMethod.muslimWorldLeague,
    school: AsrSchool.shafi,
  );

  PrayerCalculationSettings copyWith({
    PrayerCalculationMethod? method,
    AsrSchool? school,
  }) {
    return PrayerCalculationSettings(
      method: method ?? this.method,
      school: school ?? this.school,
    );
  }
}
