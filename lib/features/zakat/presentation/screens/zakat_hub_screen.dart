import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../providers/zakat_providers.dart';
import '../widgets/zakat_common.dart';
import 'zakat_agriculture_screen.dart';
import 'zakat_calculator_screen.dart';

/// Single home for everything Zakat: a fixed header with a two-way switch
/// between the wealth calculator and the agricultural calculator. The
/// educational content lives in a guide sheet and inline fact cards instead
/// of a separate screen.
class ZakatHubScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const ZakatHubScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ZakatHubScreen> createState() => _ZakatHubScreenState();
}

class _ZakatHubScreenState extends ConsumerState<ZakatHubScreen> {
  late final PageController _pages;
  late int _tab;

  static const _labels = ['Wealth', 'Harvest'];
  static const _icons = [
    Icons.account_balance_wallet_rounded,
    Icons.grass_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
    _pages = PageController(initialPage: _tab);
    // Warm the guide content so the sheet and fact cards open instantly.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(zakatInfoNotifierProvider),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    _pages.animateToPage(
      i,
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  FocusScope.of(context).unfocus();
                  setState(() => _tab = i);
                },
                children: const [ZakatCalculatorView(), ZakatAgricultureView()],
              ),
            ),
            // const BannerAdWidget(margin: EdgeInsets.symmetric(vertical: 4)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final seq = RevealSequence();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 50,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 18.h),
              child: Column(
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'الزكاة',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 26.sp,
                                color: AppColors.goldLight,
                                height: 1.3,
                              ),
                            ).slideIn(RevealDirection.top, delay: seq.next()),
                            Text(
                              'Purify your wealth',
                              style: TextStyle(
                                fontSize: 11.sp,
                                letterSpacing: 0.5,
                                color: AppColors.onHeroSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ).slideIn(
                              RevealDirection.bottom,
                              delay: seq.next(),
                            ),
                          ],
                        ),
                      ),
                      GlassIconButton(
                        icon: Icons.menu_book_rounded,
                        tooltip: 'Zakat guide',
                        onPressed: () => showZakatGuide(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _switch().slideIn(
                    RevealDirection.bottom,
                    delay: seq.next(),
                    distance: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch() {
    return Container(
      height: 52.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppColors.onHeroSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.onHeroSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Stack(
        children: [
          // Sliding gold pill follows the pager position.
          AnimatedBuilder(
            animation: _pages,
            builder: (context, _) {
              final page = _pages.hasClients
                  ? (_pages.page ?? _tab.toDouble())
                  : _tab.toDouble();
              return Align(
                alignment: Alignment(-1 + 2 * page.clamp(0.0, 1.0), 0),
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
              );
            },
          ),
          Row(
            children: List.generate(2, (i) {
              final selected = i == _tab;
              return Expanded(
                child: Pressable(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(i),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: context.motion.duration(AppMotion.fast),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.heroSurface
                            : AppColors.onHeroSurface.withValues(alpha: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icons[i],
                            size: 18.sp,
                            color: selected
                                ? AppColors.heroSurface
                                : AppColors.onHeroSurface.withValues(
                                    alpha: 0.8,
                                  ),
                          ),
                          SizedBox(width: 8.w),
                          Text(_labels[i]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
