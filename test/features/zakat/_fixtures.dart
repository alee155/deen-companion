Map<String, dynamic> breakdownJson() => {
  'cash': 10000,
  'gold_value': 5000.5,
  'silver_value': 0,
  'stocks': 0,
  'business_goods': 2500,
  'other_investments': 0,
  'gross_wealth': 17500.5,
  'liabilities': 1000,
  'net_zakatable_wealth': 16500.5,
};

Map<String, dynamic> calcJson({String standard = 'gold', bool above = true}) => {
  'zakat_due': 412.51,
  'above_nisab': above,
  'nisab_standard': standard,
  'nisab_value': 6000.0,
  'nisab_gold_grams': 87,
  'nisab_silver_grams': 612,
  'rate': '2.5%',
  'breakdown': breakdownJson(),
  'note': 'n',
};

Map<String, dynamic> agriJson({String water = 'rain'}) => {
  'value': 1000,
  'water_source': water,
  'rate': '10%',
  'zakat_due': 100,
  'note': 'n',
};

Map<String, dynamic> infoJson() => {
  'definition': 'def',
  'nisab': {
    'gold': {'grams': 87, 'description': 'g'},
    'silver': {'grams': 612, 'description': 's'},
    'note': 'nn',
  },
  'rate': {
    'general': '2.5%',
    'agriculture_rain': '10%',
    'agriculture_irrigated': '5%',
  },
  'conditions': ['a', 'b'],
  'eligible_recipients': ['poor'],
  'zakatable_assets': ['cash'],
  'non_zakatable_assets': ['house'],
  'hawl': 'one year',
  'disclaimer': 'disc',
  'source': 'src',
};

Map<String, dynamic> nisabJson({Object? goldValue = 6000.5}) => {
  'gold': {'threshold_grams': 87, 'monetary_value': goldValue, 'note': 'g'},
  'silver': {'threshold_grams': 612, 'note': 's'},
  'note': 'n',
  'zakat_rate': '2.5%',
};
