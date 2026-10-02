import 'package:flutter/material.dart';
import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../domain/entities/dua.dart';
import '../../domain/entities/dua_category.dart';
import '../screens/dua_reader_screen.dart';

const kDuaArabicFont = 'AmiriQuran';

/// Icon + tint for a category, inferred from its id/name so new categories
/// from the API still get something sensible.
class DuaCategoryStyle {
  final IconData icon;
  final Color accent;
  final Color bg;
  const DuaCategoryStyle(this.icon, this.accent, this.bg);

  static const _keywords = <(List<String>, IconData)>[
    (['morning', 'dawn', 'sunrise'], Icons.wb_sunny_rounded),
    (['evening', 'sunset'], Icons.wb_twilight_rounded),
    (['sleep', 'night', 'bed'], Icons.bedtime_rounded),
    (
      ['food', 'eat', 'meal', 'drink', 'fast', 'iftar'],
      Icons.restaurant_rounded,
    ),
    (['travel', 'journey', 'ride'], Icons.flight_takeoff_rounded),
    (['home', 'house'], Icons.home_rounded),
    (
      ['mosque', 'prayer', 'salah', 'salat', 'wudu', 'adhan'],
      Icons.mosque_rounded,
    ),
    (['forgiv', 'repent', 'istighfar', 'sin'], Icons.spa_rounded),
    (
      [
        'protect',
        'fear',
        'anx',
        'distress',
        'hardship',
        'worry',
        'grief',
        'evil',
      ],
      Icons.shield_rounded,
    ),
    (['health', 'sick', 'ill', 'heal'], Icons.healing_rounded),
    (
      ['family', 'parent', 'child', 'marriage', 'spouse'],
      Icons.family_restroom_rounded,
    ),
    (['quran'], Icons.menu_book_rounded),
    (['rain', 'weather', 'wind', 'thunder'], Icons.water_drop_rounded),
    (
      ['wealth', 'rizq', 'provision', 'debt', 'sustenance'],
      Icons.savings_rounded,
    ),
    (['knowledge', 'learn', 'study'], Icons.school_rounded),
    (['death', 'funeral', 'grave'], Icons.nights_stay_rounded),
    (['praise', 'gratitude', 'thank', 'dhikr'], Icons.auto_awesome_rounded),
  ];

  static DuaCategoryStyle of(DuaCategory c) {
    final key = '${c.id} ${c.name}'.toLowerCase();
    var icon = Icons.pan_tool_alt_rounded;
    for (final k in _keywords) {
      if (k.$1.any(key.contains)) {
        icon = k.$2;
        break;
      }
    }
    final tints = [
      (AppColors.duasAccent, AppColors.duasAccentBg),
      (AppColors.quranAccent, AppColors.quranAccentBg),
      (AppColors.hijriAccent, AppColors.hijriAccentBg),
      (AppColors.worshipAccent, AppColors.worshipAccentBg),
    ];
    final t = tints[key.codeUnits.fold<int>(0, (a, b) => a + b) % tints.length];
    return DuaCategoryStyle(icon, t.$1, t.$2);
  }
}

FavoriteItem duaFavoriteItem(Dua d) => FavoriteItem(
  id: FavoriteItem.buildId(FavoriteContentType.dua, '${d.id}'),
  type: FavoriteContentType.dua,
  referenceId: '${d.id}',
  title: d.title,
  subtitle: d.translation,
  route: '/duas',
  savedAt: DateTime.now(),
);

void openDuaReader(
  BuildContext context,
  List<Dua> duas,
  int index, {
  String? heading,
}) {
  Navigator.of(context).push(
    fadeScaleRoute(
      (_) => DuaReaderScreen(duas: duas, initialIndex: index, heading: heading),
    ),
  );
}

/// List card: numbered, with an Arabic teaser and translation preview.
class DuaPreviewCard extends StatelessWidget {
  final Dua dua;
  final int number;
  final Color accent;
  final Color bg;
  final VoidCallback onTap;

  const DuaPreviewCard({
    super.key,
    required this.dua,
    required this.number,
    required this.accent,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: AppColors.borderWarm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StarBadge(
                      label: '$number',
                      size: 34.w,
                      fill: bg,
                      stroke: accent.withValues(alpha: 0.55),
                      textColor: accent,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        dua.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkText,
                        ),
                      ),
                    ),
                    FavoriteButton(item: duaFavoriteItem(dua)),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: bg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    dua.arabic,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: kDuaArabicFont,
                      fontSize: 21.sp,
                      height: 1.9,
                      color: AppColors.inkText,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  dua.translation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 13.sp,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Text(
                        dua.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (dua.repeat > 1)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '×${dua.repeat}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16.sp,
                      color: accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
