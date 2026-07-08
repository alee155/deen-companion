import '../../domain/entities/hijri_conversion.dart';

class GregorianDateInfoModel {
  final String date;
  final String formatted;
  final String? dayOfWeek;
  final int day;
  final int month;
  final String monthName;
  final int year;

  const GregorianDateInfoModel({
    required this.date,
    required this.formatted,
    this.dayOfWeek,
    required this.day,
    required this.month,
    required this.monthName,
    required this.year,
  });

  factory GregorianDateInfoModel.fromJson(Map<String, dynamic> json) {
    return GregorianDateInfoModel(
      date: json['date'] as String,
      formatted: json['formatted'] as String,
      dayOfWeek: json['day_of_week'] as String?,
      day: json['day'] as int,
      month: json['month'] as int,
      monthName: json['month_name'] as String,
      year: json['year'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'formatted': formatted,
    'day_of_week': dayOfWeek,
    'day': day,
    'month': month,
    'month_name': monthName,
    'year': year,
  };

  GregorianDateInfo toEntity() => GregorianDateInfo(
    date: date,
    formatted: formatted,
    dayOfWeek: dayOfWeek,
    day: day,
    month: month,
    monthName: monthName,
    year: year,
  );
}

class HijriDateInfoModel {
  final String date;
  final String formatted;
  final int day;
  final int month;
  final String monthName;
  final String monthNameArabic;
  final int year;
  final String? era;

  const HijriDateInfoModel({
    required this.date,
    required this.formatted,
    required this.day,
    required this.month,
    required this.monthName,
    required this.monthNameArabic,
    required this.year,
    this.era,
  });

  factory HijriDateInfoModel.fromJson(Map<String, dynamic> json) {
    return HijriDateInfoModel(
      date: json['date'] as String,
      formatted: json['formatted'] as String,
      day: json['day'] as int,
      month: json['month'] as int,
      monthName: json['month_name'] as String,
      monthNameArabic: json['month_name_arabic'] as String,
      year: json['year'] as int,
      era: json['era'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'formatted': formatted,
    'day': day,
    'month': month,
    'month_name': monthName,
    'month_name_arabic': monthNameArabic,
    'year': year,
    'era': era,
  };

  HijriDateInfo toEntity() => HijriDateInfo(
    date: date,
    formatted: formatted,
    day: day,
    month: month,
    monthName: monthName,
    monthNameArabic: monthNameArabic,
    year: year,
    era: era,
  );
}

class HijriConversionModel {
  final GregorianDateInfoModel gregorian;
  final HijriDateInfoModel hijri;
  final String? note;

  const HijriConversionModel({
    required this.gregorian,
    required this.hijri,
    this.note,
  });

  factory HijriConversionModel.fromJson(Map<String, dynamic> json) {
    final islamicInfo = json['islamic_info'] as Map<String, dynamic>?;
    return HijriConversionModel(
      gregorian: GregorianDateInfoModel.fromJson(
        json['gregorian'] as Map<String, dynamic>,
      ),
      hijri: HijriDateInfoModel.fromJson(json['hijri'] as Map<String, dynamic>),
      note: islamicInfo?['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'gregorian': gregorian.toJson(),
    'hijri': hijri.toJson(),
    if (note != null) 'islamic_info': {'note': note},
  };

  HijriConversion toEntity() => HijriConversion(
    gregorian: gregorian.toEntity(),
    hijri: hijri.toEntity(),
    note: note,
  );
}
