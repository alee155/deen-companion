import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../providers/asma_ul_husna_providers.dart';
import '../widgets/asma_name_card.dart';

class AsmaDailyPracticeScreen extends ConsumerStatefulWidget {
  final int initialDay;
  const AsmaDailyPracticeScreen({super.key, required this.initialDay});

  @override
  ConsumerState<AsmaDailyPracticeScreen> createState() =>
      _AsmaDailyPracticeScreenState();
}

class _AsmaDailyPracticeScreenState
    extends ConsumerState<AsmaDailyPracticeScreen> {
  late int _selectedDay;
  final _controller = PageController();
  int _currentIndex = 0;
  bool _completed = false;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
  }

  @override
  Widget build(BuildContext context) {
    final dailyAsync = ref.watch(asmaDailyNotifierProvider(_selectedDay));

    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(7, (i) {
                          final day = i + 1;
                          final selected = day == _selectedDay;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedDay = day;
                              _currentIndex = 0;
                              _completed = false;
                              _controller.jumpToPage(0);
                            }),
                            child: Container(
                              width: 34.w,
                              height: 34.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.emeraldInk
                                    : Colors.transparent,
                              ),
                              child: Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: dailyAsync.when(
                  data: (daily) {
                    if (_completed)
                      return _completionView(daily.weeklyCompletion);
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            children: [
                              Text(
                                daily.suggestion,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              LinearProgressIndicator(
                                value: (_currentIndex + 1) / daily.names.length,
                                backgroundColor: AppColors.borderWarm,
                                color: AppColors.gold,
                                minHeight: 4.h,
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                '${_currentIndex + 1} of ${daily.names.length}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: daily.names.length,
                            onPageChanged: (i) =>
                                setState(() => _currentIndex = i),
                            itemBuilder: (context, index) =>
                                AsmaNameCard(name: daily.names[index]),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(20.w),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentIndex < daily.names.length - 1) {
                                  _controller.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                } else {
                                  setState(() => _completed = true);
                                }
                              },
                              child: Text(
                                _currentIndex < daily.names.length - 1
                                    ? 'Next'
                                    : 'Finish',
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                  error: (error, _) => Center(child: Text(error.toString())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _completionView(String weeklyCompletion) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppColors.emeraldInk, size: 56.sp),
            SizedBox(height: 16.h),
            Text(
              'Dhikr complete',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.inkText,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              weeklyCompletion,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
