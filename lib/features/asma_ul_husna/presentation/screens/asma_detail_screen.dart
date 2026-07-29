import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/warm_gradient_scaffold.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/asma_name.dart';
import '../widgets/asma_name_card.dart';

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
    super.dispose();
  }

  FavoriteItem _favoriteItemFor(AsmaName name) {
    return FavoriteItem(
      id: FavoriteItem.buildId(FavoriteContentType.asmaName, '${name.number}'),
      type: FavoriteContentType.asmaName,
      referenceId: '${name.number}',
      title: '${name.transliteration} (${name.english})',
      subtitle: name.meaning,
      route: '/asma-ul-husna',
      savedAt: DateTime.now(),
    );
  }

  void _logRecent() {
    final name = widget.names[_currentIndex];
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
            title: '${name.transliteration} (${name.english})',
            subtitle: name.meaning,
            route: '/asma-ul-husna',
            viewedAt: DateTime.now(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      '${widget.names[_currentIndex].number} of ${widget.names.length == 99 ? 99 : widget.names.length}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    FavoriteButton(item: _favoriteItemFor(widget.names[_currentIndex])),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.names.length,
                  onPageChanged: (i) {
                    setState(() => _currentIndex = i);
                    _logRecent();
                  },
                  itemBuilder: (context, index) =>
                      AsmaNameCard(name: widget.names[index]),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  'Swipe to explore',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
