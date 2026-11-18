import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../providers/hijri_adjustment_provider.dart';
import 'hijri_fine_tune_row.dart';

/// Lets the reader choose which Hijri date the app shows — the calculated
/// date the API returns, or the date one day earlier that Pakistan observes.
/// The provider backing this choice already existed; nothing on screen used
/// to expose it, so most people could never find it.
Future<void> showHijriAdjustmentSheet(BuildContext context, WidgetRef ref) {
  return showGroupSheet<void>(
    context,
    (_) => const _HijriAdjustmentSheetContent(),
  );
}

class _HijriAdjustmentSheetContent extends ConsumerWidget {
  const _HijriAdjustmentSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustment = ref.watch(hijriAdjustmentProvider);
    final notifier = ref.read(hijriAdjustmentProvider.notifier);

    return GroupSheetFrame(
      icon: Icons.nightlight_round,
      title: 'Hijri date adjustment',
      subtitle:
          'Moon sighting varies by region, so the observed date can run a '
          'day behind the calculated one.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetChoiceTile(
            title: 'Automatic',
            description: "Show exactly what today's date calculates to.",
            selected: adjustment == 0,
            onTap: notifier.setAutomatic,
          ),
          SizedBox(height: 10.h),
          SheetChoiceTile(
            title: 'Pakistan',
            description:
                'One day behind the calculated date — the usual gap to the '
                "Ruet-e-Hilal Committee's observed date.",
            selected: adjustment == -1,
            onTap: notifier.setPakistan,
          ),
          SizedBox(height: 10.h),
          const HijriFineTuneRow(),
        ],
      ),
    );
  }
}
