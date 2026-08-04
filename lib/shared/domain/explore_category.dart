import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Which accent family a catalog entry belongs to.
///
/// The catalog stores the *family* rather than two literal colours so it can
/// stay a `const` list while the colours themselves follow the active
/// Light/Dark palette.
enum ExploreAccent {
  quran,
  hadith,
  duas,
  hijri,
  worship,
  tools;

  Color get color => switch (this) {
    ExploreAccent.quran => AppColors.quranAccent,
    ExploreAccent.hadith => AppColors.hadithAccent,
    ExploreAccent.duas => AppColors.duasAccent,
    ExploreAccent.hijri => AppColors.hijriAccent,
    ExploreAccent.worship => AppColors.worshipAccent,
    ExploreAccent.tools => AppColors.toolsAccent,
  };

  Color get background => switch (this) {
    ExploreAccent.quran => AppColors.quranAccentBg,
    ExploreAccent.hadith => AppColors.hadithAccentBg,
    ExploreAccent.duas => AppColors.duasAccentBg,
    ExploreAccent.hijri => AppColors.hijriAccentBg,
    ExploreAccent.worship => AppColors.worshipAccentBg,
    ExploreAccent.tools => AppColors.toolsAccentBg,
  };
}

class ExploreCategory {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final ExploreAccent accent;
  final String group;
  final String route;

  const ExploreCategory({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.group,
    required this.route,
  });

  Color get accentColor => accent.color;
  Color get accentBg => accent.background;
}

class ExploreCatalog {
  ExploreCatalog._();

  static const List<ExploreCategory> all = [
    ExploreCategory(
      id: 'quran',
      label: 'Quran',
      description: 'Read, listen, and pick up where you left off',
      icon: Icons.menu_book_outlined,
      accent: ExploreAccent.quran,
      group: 'Quran & study',
      route: '/quran',
    ),
    ExploreCategory(
      id: 'mutashabihat',
      label: 'Mutashabihat',
      description: 'Similar-looking verses, compared side by side',
      icon: Icons.compare_arrows,
      accent: ExploreAccent.quran,
      group: 'Quran & study',
      route: '/mutashabihat',
    ),
    ExploreCategory(
      id: 'juz',
      label: 'Juz',
      description: 'Read the Quran in 30 parts, one Juz at a time',
      icon: Icons.auto_stories_outlined,
      accent: ExploreAccent.quran,
      group: 'Quran & study',
      route: '/juz',
    ),

    ExploreCategory(
      id: 'hadith',
      label: 'Hadith',
      description: 'Search and read from the major collections',
      icon: Icons.format_quote,
      accent: ExploreAccent.hadith,
      group: 'Knowledge & reflection',
      route: '/hadith',
    ),
    ExploreCategory(
      id: 'islamic_names',
      label: 'Islamic Names',
      description: 'Meaningful names with meanings and origins',
      icon: Icons.badge_outlined,
      accent: ExploreAccent.duas,
      group: 'Knowledge & reflection',
      route: '/islamic-names',
    ),
    ExploreCategory(
      id: 'duas',
      label: 'Duas',
      description: 'Supplications for every occasion',
      icon: Icons.back_hand_outlined,
      accent: ExploreAccent.duas,
      group: 'Knowledge & reflection',
      route: '/duas',
    ),
    ExploreCategory(
      id: 'names_of_allah',
      label: '99 Names of Allah',
      description: 'The beautiful names, with meanings',
      icon: Icons.auto_awesome_outlined,
      accent: ExploreAccent.hadith,
      group: 'Knowledge & reflection',
      route: '/asma-ul-husna',
    ),
    ExploreCategory(
      id: 'prayer_times',
      label: 'Prayer Times',
      description: "Today's timings for your location",
      icon: Icons.access_time,
      accent: ExploreAccent.worship,
      group: 'Worship & time',
      route: '/prayer-times',
    ),
    ExploreCategory(
      id: 'qibla',
      label: 'Qibla Direction',
      description: 'Find the direction of the Kaaba',
      icon: Icons.explore_outlined,
      accent: ExploreAccent.worship,
      group: 'Worship & time',
      route: '/qibla',
    ),
    ExploreCategory(
      id: 'reminders',
      label: 'Prayer Reminders',
      description: 'Get an alert at each prayer time',
      icon: Icons.notifications_active_outlined,
      accent: ExploreAccent.worship,
      group: 'Worship & time',
      route: '/reminders',
    ),
    ExploreCategory(
      id: 'islamic_calendar',
      label: 'Islamic Calendar',
      description: "This month's Hijri dates and events",
      icon: Icons.event_note_outlined,
      accent: ExploreAccent.hijri,
      group: 'Worship & time',
      route: '/islamic-calendar',
    ),
    ExploreCategory(
      id: 'zakat',
      label: 'Zakat Calculator',
      description: 'Work out what you owe this year',
      icon: Icons.calculate_outlined,
      accent: ExploreAccent.tools,
      group: 'Tools',
      route: '/zakat',
    ),
  ];

  static const List<String> homePreviewIds = [
    'quran',
    'hadith',
    'prayer_times',
    'duas',
    'islamic_calendar',
    'names_of_allah',
    'zakat',
    'islamic_names',
  ];
}
