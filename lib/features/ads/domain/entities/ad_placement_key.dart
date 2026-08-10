/// Every place in the app that shows an interstitial registers a click
/// against one of these. Each placement gets its own independent odd/even
/// counter (see `InterstitialClickCounterNotifier`), so tapping through the
/// Explore section doesn't burn through the count for Hadith, and vice
/// versa — otherwise a user bouncing between two sections could see two
/// interstitials back to back purely by coincidence of combined counts.
///
/// Add a new value here when a new placement needs interstitials; nothing
/// else about the ads feature needs to change.
enum AdPlacementKey {
  exploreSection,
  quranSurahList,
  hadithList,
  duaList,
  asmaUlHusnaList,
  islamicNamesList,
}
