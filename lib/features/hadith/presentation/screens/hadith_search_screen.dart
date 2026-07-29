import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/hadith_providers.dart';
import '../widgets/hadith_card_tile.dart';

class HadithSearchScreen extends ConsumerStatefulWidget {
  final String? currentCollection;
  const HadithSearchScreen({super.key, this.currentCollection});

  @override
  ConsumerState<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends ConsumerState<HadithSearchScreen> {
  final _controller = TextEditingController();
  bool _restrictToCollection = false;

  void _runSearch(String query) {
    ref
        .read(hadithSearchNotifierProvider.notifier)
        .search(
          query,
          collection: _restrictToCollection ? widget.currentCollection : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(hadithSearchNotifierProvider);

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
            hintText: 'Search hadith…',
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
          if (widget.currentCollection != null)
            CheckboxListTile(
              value: _restrictToCollection,
              onChanged: (v) =>
                  setState(() => _restrictToCollection = v ?? false),
              activeColor: AppColors.emeraldInk,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Only search in this collection',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.inkText,
                ),
              ),
            ),
          Expanded(
            child: searchState.when(
              data: (results) {
                if (results == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Text(
                        'Search across every collection.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (results.isEmpty)
                  return const Center(child: Text('No hadith found.'));
                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: results.length,
                  itemBuilder: (context, index) => HadithCardTile(
                    hadith: results[index],
                    onTap: () =>
                        context.push('/hadith/detail', extra: results[index]),
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: AppColors.emeraldInk),
              ),
              error: (error, _) => Center(child: Text(error.toString())),
            ),
          ),
        ],
      ),
    );
  }
}
