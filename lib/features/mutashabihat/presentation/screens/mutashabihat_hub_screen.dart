import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/mutashabihat_providers.dart';
import '../widgets/surah_picker_sheet.dart';
import 'mutashabihat_comparison_screen.dart';
import 'mutashabihat_surah_list_screen.dart';

class MutashabihatHubScreen extends ConsumerWidget {
  const MutashabihatHubScreen({super.key});

  Future<void> _lookUpVerse(BuildContext context, WidgetRef ref) async {
    final surah = await showSurahPickerSheet(context, ref);
    if (surah == null || !context.mounted) return;

    final ayahController = TextEditingController();
    final ayah = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 20.h,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ayah number',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: ayahController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 2',
                filled: true,
                fillColor: AppColors.parchment,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final value = int.tryParse(ayahController.text);
                  Navigator.of(context).pop(value);
                },
                child: const Text('Look up'),
              ),
            ),
          ],
        ),
      ),
    );

    if (ayah == null || !context.mounted) return;

    try {
      final result = await ref.read(
        mutashabihatByAyahNotifierProvider((surah, ayah)).future,
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MutashabihatComparisonScreen(entry: result),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No similar verses are known for this ayah.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(mutashabihatInfoNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Mutashabihat'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          infoAsync.when(
            data: (info) => Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.quranAccentBg,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.description,
                    style: TextStyle(fontSize: 13.sp, color: AppColors.inkText),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      _stat('${info.totalEntries}', 'Verses'),
                      _stat('${info.totalPairs}', 'Pairs'),
                      _stat('${info.surahsInvolved}', 'Surahs'),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 100),
            error: (_, __) => const SizedBox.shrink(),
          ),
          SizedBox(height: 20.h),
          _actionTile(
            context,
            icon: Icons.shuffle,
            title: 'Random Practice',
            subtitle: 'Drill a random pair of confusable verses',
            onTap: () async {
              await ref
                  .read(mutashabihatRandomNotifierProvider.notifier)
                  .next();
              final entry = ref.read(mutashabihatRandomNotifierProvider).value;
              if (entry == null || !context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _RandomPracticeScreen(),
                ),
              );
            },
          ),
          SizedBox(height: 10.h),
          _actionTile(
            context,
            icon: Icons.menu_book_outlined,
            title: 'Browse by Surah',
            subtitle: 'See confusable verses within one surah',
            onTap: () async {
              final surah = await showSurahPickerSheet(context, ref);
              if (surah == null || !context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      MutashabihatSurahListScreen(surah: surah),
                ),
              );
            },
          ),
          SizedBox(height: 10.h),
          _actionTile(
            context,
            icon: Icons.search,
            title: 'Look Up a Verse',
            subtitle: 'Check if a specific ayah has known lookalikes',
            onTap: () => _lookUpVerse(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.quranAccent,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.sp, color: AppColors.inkText),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.borderWarm),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: AppColors.quranAccentBg,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: AppColors.quranAccent, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18.sp),
          ],
        ),
      ),
    );
  }
}

class _RandomPracticeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(mutashabihatRandomNotifierProvider);

    return entryAsync.when(
      data: (entry) {
        if (entry == null)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        return MutashabihatComparisonScreen(
          entry: entry,
          onNext: () =>
              ref.read(mutashabihatRandomNotifierProvider.notifier).next(),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text(error.toString()))),
    );
  }
}
