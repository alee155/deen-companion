class GregorianDateInfo {
  final String date;
  final String formatted;
  final String? dayOfWeek;
  final int day;
  final int month;
  final String monthName;
  final int year;

  const GregorianDateInfo({
    required this.date,
    required this.formatted,
    this.dayOfWeek,
    required this.day,
    required this.month,
    required this.monthName,
    required this.year,
  });
}

class HijriDateInfo {
  final String date;
  final String formatted;
  final int day;
  final int month;
  final String monthName;
  final String monthNameArabic;
  final int year;
  final String? era;

  const HijriDateInfo({
    required this.date,
    required this.formatted,
    required this.day,
    required this.month,
    required this.monthName,
    required this.monthNameArabic,
    required this.year,
    this.era,
  });
}

class HijriConversion {
  final GregorianDateInfo gregorian;
  final HijriDateInfo hijri;
  final String? note;

  const HijriConversion({
    required this.gregorian,
    required this.hijri,
    this.note,
  });
}
