import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../quran/presentation/providers/quran_providers.dart';

Future<int?> showSurahPickerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => const _SurahPickerContent(),
  );
}

class _SurahPickerContent extends ConsumerStatefulWidget {
  const _SurahPickerContent();

  @override
  ConsumerState<_SurahPickerContent> createState() =>
      _SurahPickerContentState();
}

class _SurahPickerContentState extends ConsumerState<_SurahPickerContent> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final surahsAsync = ref.watch(surahListNotifierProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.borderWarm,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search surah…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.parchment,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: surahsAsync.when(
                  data: (surahs) {
                    final filtered = _query.isEmpty
                        ? surahs
                        : surahs
                              .where(
                                (s) => s.nameEnglish.toLowerCase().contains(
                                  _query,
                                ),
                              )
                              .toList();
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.quranAccentBg,
                            child: Text(
                              '${s.number}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.quranAccent,
                              ),
                            ),
                          ),
                          title: Text(s.nameEnglish),
                          subtitle: Text(s.nameTranslation),
                          onTap: () => Navigator.of(context).pop(s.number),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text(error.toString())),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
