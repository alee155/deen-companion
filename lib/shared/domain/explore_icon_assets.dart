/// Maps an [ExploreCategory.id] to a real icon asset, for the grid tiles on
/// Explore (and Home) that use full-color illustrated icons instead of a
/// tinted Material icon. Categories with no entry here fall back to their
/// [ExploreCategory.icon] — a deliberate placeholder until a matching asset
/// is supplied.
const Map<String, String> exploreIconAssets = {
  'quran': 'assets/images/quran_icon.png',
  'hadith': 'assets/images/hadees_icon.png',
  'islamic_names': 'assets/images/names_icon.png',
  'duas': 'assets/images/dua_icon.png',
  'names_of_allah': 'assets/images/Allah_icon.png',
  'prayer_times': 'assets/images/cl.png',
  'islamic_calendar': 'assets/images/calendar_icon.png',
  'zakat': 'assets/images/zakat_icon.png',
  'mutashabihat': 'assets/images/mutashabihat.png',
  'juz': 'assets/images/juzz.png',
  'qibla': 'assets/images/compass.png',
  'reminders': 'assets/images/reminder.png',
};
