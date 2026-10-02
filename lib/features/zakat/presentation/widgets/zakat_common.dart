import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/entities/zakat_info.dart';
import '../providers/zakat_providers.dart';

/// 1234567.891 → "1,234,567.89"
String zakatFmt(double v, {int decimals = 2}) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final out = parts.length > 1 ? '$whole.${parts[1]}' : whole;
  return neg ? '-$out' : out;
}

double zakatNum(TextEditingController c) =>
    double.tryParse(c.text.replaceAll(',', '')) ?? 0;

/// Accent used across the Zakat experience.
Color get zakatAccent => AppColors.toolsAccent;
Color get zakatAccentBg => AppColors.toolsAccentBg;

/// Large, friendly numeric input.
class ZakatMoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? suffix;
  final ValueChanged<String>? onChanged;
  final bool large;

  const ZakatMoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.suffix,
    this.onChanged,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 6.h),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(
            fontSize: large ? 28.sp : 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
          decoration: InputDecoration(
            hintText: hint ?? '0',
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 20.sp, color: zakatAccent),
            suffixText: suffix,
            filled: true,
            fillColor: AppColors.parchment,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: large ? 18.h : 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: AppColors.borderWarm),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: AppColors.borderWarm),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: zakatAccent, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card surface used for grouped content.
class ZakatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  const ZakatCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: borderColor ?? AppColors.borderWarm),
      ),
      child: child,
    );
  }
}

/// Horizontal strip of "good to know" facts drawn from [ZakatInfo].
/// Tapping any card opens the full guide.
class ZakatFactStrip extends ConsumerWidget {
  final List<ZakatFact> Function(ZakatInfo info) factsFor;
  const ZakatFactStrip({super.key, required this.factsFor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(zakatInfoNotifierProvider).valueOrNull;
    if (info == null) return const SizedBox.shrink();
    final facts = factsFor(info);
    return SizedBox(
      height: 112.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: facts.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.w),
        itemBuilder: (context, i) {
          final f = facts[i];
          return Pressable(
            onTap: () => showZakatGuide(context),
            child: Container(
              width: 168.w,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: zakatAccentBg,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: zakatAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(f.icon, size: 15.sp, color: zakatAccent),
                      SizedBox(width: 6.w),
                      Text(
                        f.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: zakatAccent,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    f.value,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkText,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Expanded(
                    child: Text(
                      f.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.sp,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).slideInAt(i, distance: 20);
        },
      ),
    );
  }
}

class ZakatFact {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  const ZakatFact(this.icon, this.label, this.value, this.detail);
}

/// Opens the full Zakat guide (what used to be the "About Zakat" screen).
void showZakatGuide(BuildContext context) {
  showModalBottomSheet<void>(
    sheetAnimationStyle: AppMotion.sheetStyle,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ZakatGuideSheet(),
  );
}

class _ZakatGuideSheet extends ConsumerStatefulWidget {
  const _ZakatGuideSheet();

  @override
  ConsumerState<_ZakatGuideSheet> createState() => _ZakatGuideSheetState();
}

class _ZakatGuideSheetState extends ConsumerState<_ZakatGuideSheet> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(zakatInfoNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.parchment,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: infoAsync.when(
            data: (info) => _content(info, scroll),
            loading: () =>
                Center(child: CircularProgressIndicator(color: zakatAccent)),
            error: (e, _) => Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Text(e.toString(), textAlign: TextAlign.center),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(ZakatInfo info, ScrollController scroll) {
    final seq = RevealSequence();
    final sections = <(String, IconData, List<String>)>[
      ('Conditions', Icons.rule_rounded, info.conditions),
      (
        'Zakatable assets',
        Icons.check_circle_outline_rounded,
        info.zakatableAssets,
      ),
      (
        'Not zakatable',
        Icons.do_not_disturb_alt_rounded,
        info.nonZakatableAssets,
      ),
      (
        'Who can receive it',
        Icons.volunteer_activism_rounded,
        info.eligibleRecipients,
      ),
    ];

    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 32.h),
      children: [
        Center(
          child: Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.borderWarm,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
        SizedBox(height: 18.h),
        Text(
          'Understanding Zakat',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.inkText,
          ),
        ).slideIn(RevealDirection.start, delay: seq.next()),
        SizedBox(height: 8.h),
        Text(
          info.definition,
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ).slideIn(RevealDirection.bottom, delay: seq.next()),
        SizedBox(height: 16.h),
        Row(
          children: [
            _stat('Gold nisab', '${info.nisabGold.grams} g'),
            SizedBox(width: 8.w),
            _stat('Silver nisab', '${info.nisabSilver.grams} g'),
            SizedBox(width: 8.w),
            _stat('Rate', info.rateGeneral),
          ],
        ),
        SizedBox(height: 10.h),
        ZakatCard(
          color: zakatAccentBg,
          borderColor: zakatAccent.withValues(alpha: 0.2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hourglass_bottom_rounded,
                size: 18.sp,
                color: zakatAccent,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  info.hawl,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.5,
                    color: AppColors.inkText,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        for (var i = 0; i < sections.length; i++)
          _accordion(i, sections[i].$1, sections[i].$2, sections[i].$3),
        SizedBox(height: 8.h),
        Text(
          '${info.nisabNote}\n\n${info.disclaimer}',
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.55,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: AppColors.heroSurface,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.goldLight,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppColors.onHeroSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accordion(
    int index,
    String title,
    IconData icon,
    List<String> items,
  ) {
    final open = _open == index;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: ZakatCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            PressScale(
              scale: AppMotion.pressScale,
              child: InkWell(
                borderRadius: BorderRadius.circular(22.r),
                onTap: () => setState(() => _open = open ? -1 : index),
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: zakatAccentBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16.sp, color: zakatAccent),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: context.motion.duration(AppMotion.fast),
                        curve: AppMotion.entrance,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ExpandSection(
              expanded: open,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                child: Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Icon(
                                Icons.circle,
                                size: 5.sp,
                                color: zakatAccent,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
