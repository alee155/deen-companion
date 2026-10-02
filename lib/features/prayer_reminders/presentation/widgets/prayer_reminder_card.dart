import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/widgets/prayer_hero.dart'
    show prayerArabic, prayerIcons, prayerLabels;
import '../../domain/prayer_reminder_prefs.dart';

/// One prayer's reminder settings, as a compact card: icon, name, time and a
/// one-line summary with the alarm switch always in reach. Tapping expands
/// the snooze settings in place — so the five prayers stay scannable and the
/// detail only appears for the one being edited.
class PrayerReminderCard extends StatelessWidget {
  final PrayerName prayer;
  final DateTime? time;
  final PrayerReminderPrefs prefs;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<PrayerReminderPrefs> onChanged;

  const PrayerReminderCard({
    super.key,
    required this.prayer,
    required this.time,
    required this.prefs,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onChanged,
  });

  String get _summary {
    if (!prefs.enabled) return 'Reminder off';
    return prefs.snoozeEnabled
        ? 'Alarm on · Snooze ${prefs.snoozeMinutes} min'
        : 'Alarm on · No snooze';
  }

  @override
  Widget build(BuildContext context) {
    final active = prefs.enabled;
    final open = expanded && active;

    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.normal),
      curve: AppMotion.emphasized,
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(
                AppColors.emeraldInk.withValues(alpha: open ? 0.05 : 0),
                AppColors.surfaceLight,
              )
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: open
              ? AppColors.emeraldInk.withValues(alpha: 0.4)
              : AppColors.borderWarm,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22.r),
            onTap: active ? onToggleExpanded : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 8.w, 12.h),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: context.motion.duration(AppMotion.normal),
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.worshipAccentBg
                          : AppColors.borderWarm.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    child: Icon(
                      prayerIcons[prayer],
                      size: 22.sp,
                      color: active
                          ? AppColors.worshipAccent
                          : AppColors.textMuted,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              prayerLabels[prayer]!,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? AppColors.inkText
                                    : AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              prayerArabic[prayer]!,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 14.sp,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Row(
                          children: [
                            Text(
                              time == null
                                  ? '—'
                                  : DateFormat('h:mm a').format(time!),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? AppColors.worshipAccent
                                    : AppColors.textMuted,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: AnimatedText(
                                _summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: active,
                    activeThumbColor: AppColors.emeraldInk,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      onChanged(prefs.copyWith(enabled: v));
                    },
                  ),
                  SizedBox(
                    width: 22.w,
                    child: active
                        ? AnimatedRotation(
                            turns: open ? 0.5 : 0,
                            duration: context.motion.duration(AppMotion.normal),
                            curve: AppMotion.emphasized,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22.sp,
                              color: AppColors.textMuted,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          ExpandSection(
            expanded: open,
            child: _Details(prefs: prefs, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  final PrayerReminderPrefs prefs;
  final ValueChanged<PrayerReminderPrefs> onChanged;

  const _Details({required this.prefs, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
      child: Column(
        children: [
          Divider(height: 1, color: AppColors.borderWarm),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(
                Icons.snooze_rounded,
                size: 19.sp,
                color: AppColors.worshipAccent,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Snooze',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                    Text(
                      'Ring again after a short delay',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: prefs.snoozeEnabled,
                activeThumbColor: AppColors.emeraldInk,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onChanged(prefs.copyWith(snoozeEnabled: v));
                },
              ),
            ],
          ),
          ExpandSection(
            expanded: prefs.snoozeEnabled,
            child: Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Row(
                children: [
                  for (final minutes in PrayerReminderPrefs.snoozeOptions) ...[
                    Expanded(
                      child: _DurationChip(
                        minutes: minutes,
                        selected: prefs.snoozeMinutes == minutes,
                        onTap: () {
                          if (prefs.snoozeMinutes == minutes) return;
                          HapticFeedback.selectionClick();
                          onChanged(prefs.copyWith(snoozeMinutes: minutes));
                        },
                      ),
                    ),
                    if (minutes != PrayerReminderPrefs.snoozeOptions.last)
                      SizedBox(width: 8.w),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.motion.duration(AppMotion.fast),
        curve: AppMotion.entrance,
        padding: EdgeInsets.symmetric(vertical: 9.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.emeraldInk : AppColors.worshipAccentBg,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Text(
          '$minutes min',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.onEmeraldInk : AppColors.worshipAccent,
          ),
        ),
      ),
    );
  }
}
