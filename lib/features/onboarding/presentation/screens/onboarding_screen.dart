import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';

class _OnboardingPage {
  final String image;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.description,
  });
}

const _pages = [
  _OnboardingPage(
    image: 'assets/images/one.png',
    title: 'The Quran, beautifully presented',
    description:
        'Read, listen, and search the full Quran with translations, tafsir, and recitation from 13 reciters all in one place.',
  ),
  _OnboardingPage(
    image: 'assets/images/four.png',
    title: 'Never miss a prayer',
    description:
        'Accurate prayer times and Qibla direction based on your location, with a live compass to guide you.',
  ),
  _OnboardingPage(
    image: 'assets/images/two.png',
    title: 'Hadith, Duas, and daily reflection',
    description:
        'Explore thousands of authentic hadith, daily duas, the 99 Names of Allah, and more built for everyday use.',
  ),
  _OnboardingPage(
    image: 'assets/images/three.png',
    title: 'Made for your daily journey',
    description:
        'Save your favorites, track recent reading, and calculate your Zakat all designed to feel calm and unhurried.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.put(
      AppConstants.settingsBoxName,
      AppConstants.onboardingCompletedKey,
      true,
    );
    if (!mounted) return;
    // Straight into the permission rationale — the first thing after
    // onboarding is the one thing the app needs from the user.
    context.go('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          page.image,
                          width: 360.w,
                          height: 360.h,
                          fit: BoxFit.contain,
                        ),

                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: i == _index ? 20.w : 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.emeraldInk
                        : AppColors.borderWarm,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                );
              }),
            ),
            Padding(
              padding: EdgeInsets.all(24.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
