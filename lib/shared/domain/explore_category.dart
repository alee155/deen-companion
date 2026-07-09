import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ExploreCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final String group;
  final String route;

  const ExploreCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    required this.group,
    required this.route,
  });
}

class ExploreCatalog {
  ExploreCatalog._();

  static const List<ExploreCategory> all = [
    ExploreCategory(
      id: 'quran',
      label: 'Quran',
      icon: Icons.menu_book_outlined,
      accentColor: AppColors.quranAccent,
      accentBg: AppColors.quranAccentBg,
      group: 'Quran & study',
      route: '/quran',
    ),
    ExploreCategory(
      id: 'tafsir',
      label: 'Tafsir',
      icon: Icons.auto_stories_outlined,
      accentColor: AppColors.quranAccent,
      accentBg: AppColors.quranAccentBg,
      group: 'Quran & study',
      route: '',
    ),
    ExploreCategory(
      id: 'mutashabihat',
      label: 'Mutashabihat',
      icon: Icons.compare_arrows,
      accentColor: AppColors.quranAccent,
      accentBg: AppColors.quranAccentBg,
      group: 'Quran & study',
      route: '/mutashabihat',
    ),
    ExploreCategory(
      id: 'hadith',
      label: 'Hadith',
      icon: Icons.format_quote,
      accentColor: AppColors.hadithAccent,
      accentBg: AppColors.hadithAccentBg,
      group: 'Knowledge & reflection',
      route: '/learn',
    ),
    ExploreCategory(
      id: 'duas',
      label: 'Duas',
      icon: Icons.back_hand_outlined,
      accentColor: AppColors.duasAccent,
      accentBg: AppColors.duasAccentBg,
      group: 'Knowledge & reflection',
      route: '/duas',
    ),
    ExploreCategory(
      id: 'names_of_allah',
      label: '99 Names of Allah',
      icon: Icons.auto_awesome_outlined,
      accentColor: AppColors.duasAccent,
      accentBg: AppColors.duasAccentBg,
      group: 'Knowledge & reflection',
      route: '/asma-ul-husna',
    ),
    ExploreCategory(
      id: 'islamic_names',
      label: 'Islamic Names',
      icon: Icons.badge_outlined,
      accentColor: AppColors.duasAccent,
      accentBg: AppColors.duasAccentBg,
      group: 'Knowledge & reflection',
      route: '',
    ),
    ExploreCategory(
      id: 'prayer_times',
      label: 'Prayer Times',
      icon: Icons.access_time,
      accentColor: AppColors.worshipAccent,
      accentBg: AppColors.worshipAccentBg,
      group: 'Worship & time',
      route: '/prayer-times',
    ),
    ExploreCategory(
      id: 'qibla',
      label: 'Qibla Direction',
      icon: Icons.explore_outlined,
      accentColor: AppColors.worshipAccent,
      accentBg: AppColors.worshipAccentBg,
      group: 'Worship & time',
      route: '/qibla',
    ),
    ExploreCategory(
      id: 'islamic_calendar',
      label: 'Islamic Calendar',
      icon: Icons.event_note_outlined,
      accentColor: AppColors.hijriAccent,
      accentBg: AppColors.hijriAccentBg,
      group: 'Worship & time',
      route: '/islamic-calendar',
    ),
    ExploreCategory(
      id: 'moon_sighting',
      label: 'Moon Sighting',
      icon: Icons.nightlight_round,
      accentColor: AppColors.worshipAccent,
      accentBg: AppColors.worshipAccentBg,
      group: 'Worship & time',
      route: '',
    ),
    ExploreCategory(
      id: 'zakat',
      label: 'Zakat Calculator',
      icon: Icons.calculate_outlined,
      accentColor: AppColors.toolsAccent,
      accentBg: AppColors.toolsAccentBg,
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
  ];
}
