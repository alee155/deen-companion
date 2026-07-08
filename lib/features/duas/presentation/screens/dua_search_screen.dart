import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/dua_providers.dart';
import '../widgets/dua_card_tile.dart';

class DuaSearchScreen extends ConsumerStatefulWidget {
  const DuaSearchScreen({super.key});

  @override
  ConsumerState<DuaSearchScreen> createState() => _DuaSearchScreenState();
}

class _DuaSearchScreenState extends ConsumerState<DuaSearchScreen> {
  final _controller = TextEditingController();
  String? _activeCategoryFilter;

  void _runSearch(String query) {
    setState(() => _activeCategoryFilter = null);
    ref.read(duaSearchNotifierProvider.notifier).search(query);
  }

  void _tapSuggestion(String categoryId, String categoryName) {
    _controller.text = categoryName;
    setState(() => _activeCategoryFilter = categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(duaSearchNotifierProvider);
    final bundleAsync = ref.watch(duasBundleNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search duas…',
            border: InputBorder.none,
          ),
          onSubmitted: _runSearch,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _runSearch(_controller.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category suggestions — shown until a real search/filter is active.
          if (_activeCategoryFilter == null && searchState.value == null)
            bundleAsync.when(
              data: (bundle) => Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse by category',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: bundle.categories.map((c) {
                        return GestureDetector(
                          onTap: () => _tapSuggestion(c.id, c.name),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 7.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.duasAccentBg,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              c.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.duasAccent,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          Expanded(
            child: _activeCategoryFilter != null
                ? bundleAsync.when(
                    data: (bundle) {
                      final duas = bundle.byCategory(_activeCategoryFilter!);
                      return ListView.builder(
                        itemCount: duas.length,
                        itemBuilder: (context, index) =>
                            DuaCardTile(dua: duas[index]),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.emeraldInk,
                      ),
                    ),
                    error: (error, _) => Center(child: Text(error.toString())),
                  )
                : searchState.when(
                    data: (results) {
                      if (results == null) return const SizedBox.shrink();
                      if (results.isEmpty)
                        return const Center(child: Text('No duas found.'));
                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) =>
                            DuaCardTile(dua: results[index]),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.emeraldInk,
                      ),
                    ),
                    error: (error, _) => Center(child: Text(error.toString())),
                  ),
          ),
        ],
      ),
    );
  }
}
