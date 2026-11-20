import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/utils/share_text.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pager_controls.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/asma_name.dart';
import '../widgets/asma_cards.dart';
import '../widgets/asma_ornaments.dart';

/// One Name of Allah, set out the way the Ayat & Hadith of the Day screen is:
/// the same hero, then reading cards. Swipe, or use the controls, to move
/// between the Names; the counter under the card is for reciting the Name.
class AsmaDetailScreen extends ConsumerStatefulWidget {
  final List<AsmaName> names;
  final int initialIndex;

  const AsmaDetailScreen({
    super.key,
    required this.names,
    required this.initialIndex,
  });

  @override
  ConsumerState<AsmaDetailScreen> createState() => _AsmaDetailScreenState();
}

class _AsmaDetailScreenState extends ConsumerState<AsmaDetailScreen> {
  late final PageController _controller;
  late int _currentIndex;

  /// The back button floats over the hero; the hero itself never scrolls away
  /// here (the Names page sideways), so the bar stays transparent.
  final _bar = ValueNotifier<double>(0);

  /// Tasbih counts keep for the lifetime of the screen, per Name number.
  final Map<int, int> _counts = {};
  int _target = 33;

  static const _targets = [3, 7, 33, 99];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _logRecent());
  }

  @override
  void dispose() {
    _controller.dispose();
    _bar.dispose();
    super.dispose();
  }

  AsmaName get _current => widget.names[_currentIndex];

  /// What is saved is the English, whatever is shown: Favorites and Recent look
  /// the Name up by its number to show it in the reader's language.
  FavoriteItem _favoriteItemFor(AsmaName name) => FavoriteItem(
    id: FavoriteItem.buildId(FavoriteContentType.asmaName, '${name.number}'),
    type: FavoriteContentType.asmaName,
    referenceId: '${name.number}',
    title: '${name.transliteration} (${name.englishEpithet})',
    subtitle: name.englishMeaning,
    route: '/asma-ul-husna',
    savedAt: DateTime.now(),
  );

  void _logRecent() {
    final name = _current;
    ref
        .read(recentActivityNotifierProvider.notifier)
        .logActivity(
          RecentActivityItem(
            id: RecentActivityItem.buildId(
              RecentActivityType.asmaName,
              '${name.number}',
            ),
            type: RecentActivityType.asmaName,
            referenceId: '${name.number}',
            title: '${name.transliteration} (${name.englishEpithet})',
            subtitle: name.englishMeaning,
            route: '/asma-ul-husna',
            viewedAt: DateTime.now(),
          ),
        );
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.names.length) return;
    _controller.animateToPage(
      index,
      duration: context.motion.duration(AppMotion.slow),
      curve: AppMotion.emphasized,
    );
  }

  void _tap(AsmaName name) {
    final next = (_counts[name.number] ?? 0) + 1;
    if (next == _target) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() => _counts[name.number] = next);
  }

  /// What is copied and shared is what is on the screen: in Urdu, the Urdu, and
  /// no meaning at all where there is no Urdu one, never the English.
  String _shareText(AsmaName n) => [
    n.arabic,
    '${n.transliteration} — ${n.english}',
    if (n.meaning.trim().isNotEmpty) n.meaning,
  ].join('\n\n');

  void _copy(AsmaName n) {
    Clipboard.setData(ClipboardData(text: _shareText(n)));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.names.length;
    final tint = AsmaTint.of(_current.number);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            Column(
              children: [
                FeatureHero(
                  compact: true,
                  animate: false,
                  title: 'Names of Allah',
                  subtitle: 'Name ${_current.number} of 99',
                  ghostIcon: Icons.auto_awesome_rounded,
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentIndex = i);
                      _logRecent();
                    },
                    itemBuilder: (context, index) => _page(widget.names[index]),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: PagerControls(
                    page: _currentIndex,
                    count: total,
                    accent: tint.accent,
                    onPrevious: _currentIndex > 0
                        ? () => _goTo(_currentIndex - 1)
                        : null,
                    onNext: _currentIndex < total - 1
                        ? () => _goTo(_currentIndex + 1)
                        : null,
                    onSeek: (i) => _controller.jumpToPage(i),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: ''),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page(AsmaName name) {
    final tint = AsmaTint.of(name.number);
    final count = _counts[name.number] ?? 0;
    final reached = count >= _target;

    return SingleChildScrollView(
      key: PageStorageKey('name${name.number}'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
      child: Column(
        children: [
          AsmaNameCard(
            name: name,
            actions: [
              FavoriteButton(item: _favoriteItemFor(name), size: 22),
              InkResponse(
                onTap: () => _copy(name),
                radius: 22.r,
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: tint.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16.sp,
                    color: tint.accent,
                  ),
                ),
              ),
              InkResponse(
                onTap: () => shareText(context, _shareText(name)),
                radius: 22.r,
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: AppColors.worshipAccentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.ios_share_rounded,
                    size: 17.sp,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ),
            ],
          ).celebrate(key: ValueKey('card${name.number}')),
          SizedBox(height: 14.h),
          AsmaTasbihCard(
            tint: tint,
            count: count,
            target: _target,
            targets: _targets,
            title: reached ? 'Target reached' : 'Tap to recite',
            onTap: () => _tap(name),
            onTarget: (t) => setState(() => _target = t),
            onReset: () => setState(() => _counts[name.number] = 0),
          ).slideIn(
            RevealDirection.bottom,
            delay: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
