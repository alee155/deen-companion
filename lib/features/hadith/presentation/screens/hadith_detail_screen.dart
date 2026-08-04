import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/widgets/deen_app_bar.dart';
import '../../../favorites/domain/entities/favorite_item.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../recent_activity/domain/entities/recent_activity_item.dart';
import '../../../recent_activity/presentation/providers/recent_activity_providers.dart';
import '../../domain/entities/hadith.dart';
import '../providers/hadith_providers.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../widgets/hadith_reader_page.dart';
import '../../../../shared/widgets/reader_settings_sheet.dart';

/// A single hadith, opened from search or from Favorites.
///
/// Renders through the same [HadithReaderPage] as the sequential reader, so the
/// typography, spacing and font-size preferences are identical wherever a
/// hadith is read — one reading experience, two entry points.
class HadithDetailScreen extends ConsumerStatefulWidget {
  final Hadith hadith;
  const HadithDetailScreen({super.key, required this.hadith});

  @override
  ConsumerState<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends ConsumerState<HadithDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Logged once per visit, after the first frame — not on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hadith = widget.hadith;
      ref
          .read(recentActivityNotifierProvider.notifier)
          .logActivity(
            RecentActivityItem(
              id: RecentActivityItem.buildId(
                RecentActivityType.hadith,
                hadith.id,
              ),
              type: RecentActivityType.hadith,
              referenceId: hadith.id,
              title: '${hadith.collectionName} · Hadith ${hadith.hadithNumber}',
              subtitle: hadith.english,
              route: '/hadith/read/${hadith.collection}',
              viewedAt: DateTime.now(),
            ),
          );
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.hadith.toShareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hadith copied, with its reference')),
    );
  }

  Future<void> _share() => Share.share(
    widget.hadith.toShareText(),
    subject: widget.hadith.collectionName,
  );

  @override
  Widget build(BuildContext context) {
    final hadith = widget.hadith;
    final preferences = ref.watch(readingPreferencesProvider);
    final collection = ref.watch(
      hadithCollectionByKeyProvider(hadith.collection),
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: DeenAppBar(
        title: collection?.name ?? hadith.collectionName,
        subtitle: 'Hadith ${hadith.hadithNumber}',
        actions: [
          FavoriteButton(
            size: 20,
            item: FavoriteItem(
              id: FavoriteItem.buildId(FavoriteContentType.hadith, hadith.id),
              type: FavoriteContentType.hadith,
              referenceId: hadith.id,
              title: '${hadith.collectionName} · Hadith ${hadith.hadithNumber}',
              subtitle: hadith.english,
              route: '/hadith/read/${hadith.collection}',
              savedAt: DateTime.now(),
            ),
          ),
          IconButton(
            tooltip: 'Reading settings',
            icon: const Icon(Icons.text_fields_rounded),
            onPressed: () => showReaderSettingsSheet(context),
          ),
          IconButton(
            tooltip: 'Copy hadith',
            icon: const Icon(Icons.copy_rounded),
            onPressed: _copy,
          ),
          IconButton(
            tooltip: 'Share hadith',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _share,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: HadithReaderPage(
              hadith: hadith,
              collection: collection,
              preferences: preferences,
            ).appear(),
          ),
          // From a single hadith, the obvious next step is the book it came
          // from — otherwise this screen is a dead end.
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/hadith/read/${hadith.collection}'),
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: Text(
                    'Read ${collection?.name ?? hadith.collectionName}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
