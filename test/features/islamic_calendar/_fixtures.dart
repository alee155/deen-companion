Map<String, dynamic> gregorianJson({
  String date = '2026-06-16',
  int day = 16,
  int month = 6,
  int year = 2026,
}) => {
  'date': date,
  'formatted': 'Tuesday, June 16, 2026',
  'day_of_week': 'Tuesday',
  'day': day,
  'month': month,
  'month_name': 'June',
  'year': year,
};

Map<String, dynamic> hijriJson({int day = 1, int month = 1, int year = 1448}) => {
  'date': '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
  'formatted': '$day Muharram $year AH',
  'day': day,
  'month': month,
  'month_name': 'Muharram',
  'month_name_arabic': 'محرم',
  'year': year,
  'era': 'AH',
};

Map<String, dynamic> conversionJson({String? note = 'Calculated date'}) => {
  'gregorian': gregorianJson(),
  'hijri': hijriJson(),
  if (note != null) 'islamic_info': {'note': note},
};

Map<String, dynamic> eventsBundleJson() => {
  'current_hijri_date': conversionJson(),
  'next_event': {
    'name': 'Ashura',
    'hijri_date': '10 Muharram 1448',
    'month': 1,
    'day': 10,
  },
  'events': [
    {'month': 1, 'day': 1, 'name': 'Islamic New Year', 'description': 'd1'},
    {'month': 9, 'day': 1, 'name': 'Ramadan begins', 'description': 'd2'},
  ],
};

Map<String, dynamic> monthJson(int n) => {
  'number': n,
  'name_english': 'Month$n',
  'name_arabic': 'm$n',
  'significance': 's$n',
};
