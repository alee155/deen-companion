import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';
import '../../domain/entities/prayer_calculation_settings.dart';
import '../providers/prayer_calculation_settings_provider.dart';
import '../providers/prayer_times_loader.dart';

/// Pick-one sheets for the prayer calculation settings, in the same style as
/// the app's other sheets: a textured header over a soft body.
Future<void> showCalculationMethodPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(prayerCalculationSettingsProvider).method;

  return showGroupSheet<void>(
    context,
    (sheetContext) => GroupSheetFrame(
      icon: Icons.calculate_rounded,
      title: 'Calculation method',
      subtitle:
          'Choose the method your local mosque or authority uses. Times can '
          'shift by several minutes between methods.',
      pinHeader: true,
      child: Consumer(
        builder: (context, ref, _) {
          final options =
              ref.watch(prayerMethodOptionsProvider).valueOrNull ??
              [
                for (final m in PrayerCalculationMethod.values)
                  (method: m, label: m.label),
              ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options) ...[
                SheetChoiceTile(
                  title: option.label,
                  selected: option.method == current,
                  onTap: () {
                    ref
                        .read(prayerCalculationSettingsProvider.notifier)
                        .setMethod(option.method);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                SizedBox(height: 10.h),
              ],
            ],
          );
        },
      ),
    ),
  );
}

Future<void> showAsrSchoolPicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(prayerCalculationSettingsProvider).school;

  return showGroupSheet<void>(
    context,
    (sheetContext) => GroupSheetFrame(
      icon: Icons.wb_twilight_rounded,
      title: 'Asr juristic school',
      subtitle: 'Hanafi Asr falls later than Shafi/Maliki/Hanbali Asr.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final school in AsrSchool.values) ...[
            SheetChoiceTile(
              title: school.label,
              selected: school == current,
              onTap: () {
                ref
                    .read(prayerCalculationSettingsProvider.notifier)
                    .setSchool(school);
                Navigator.of(sheetContext).pop();
              },
            ),
            SizedBox(height: 10.h),
          ],
        ],
      ),
    ),
  );
}
