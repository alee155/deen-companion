import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/islamic_name.dart';
import '../../domain/services/islamic_names_filter.dart';
import '../providers/islamic_names_providers.dart';
import '../widgets/islamic_name_list_tile.dart';
import '../widgets/origin_filter_sheet.dart';
import 'islamic_name_detail_screen.dart';

class IslamicNamesHubScreen extends ConsumerStatefulWidget {
  const IslamicNamesHubScreen({super.key});

  @override
  ConsumerState<IslamicNamesHubScreen> createState() =>
      _IslamicNamesHubScreenState();
}

class _IslamicNamesHubScreenState extends ConsumerState<IslamicNamesHubScreen> {
  String _query = '';
  String _genderFilter = 'all';
  Set<String> _originFilters = {};

  void _openDetail(List<IslamicName> pool, IslamicName name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IslamicNameDetailScreen(
          name: name,
          onShuffle: () {
            final random = pool[Random().nextInt(pool.length)];
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    IslamicNameDetailScreen(name: random, onShuffle: () {}),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(islamicNamesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Islamic Names'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: namesAsync.when(
        data: (allNames) {
          final origins = IslamicNamesFilter.uniqueOrigins(allNames);
          final filtered = IslamicNamesFilter.apply(
            allNames,
            genderFilter: _genderFilter,
            originFilters: _originFilters,
            query: _query,
          );
          final grouped = IslamicNamesFilter.groupAlphabetically(filtered);

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or meaning…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.borderWarm),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _genderTab('All', 'all')),
                            Expanded(child: _genderTab('Boy', 'male')),
                            Expanded(child: _genderTab('Girl', 'female')),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await showOriginFilterSheet(
                          context,
                          allOrigins: origins,
                          initiallySelected: _originFilters,
                        );
                        if (result != null)
                          setState(() => _originFilters = result);
                      },
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                        _originFilters.isEmpty
                            ? 'Origin'
                            : '${_originFilters.length}',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No names match your filters.'))
                    : ListView(
                        children: grouped.entries.expand((entry) {
                          return [
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                20.w,
                                10.h,
                                20.w,
                                4.h,
                              ),
                              color: AppColors.parchment,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                            ...entry.value.map(
                              (n) => IslamicNameListTile(
                                name: n,
                                onTap: () => _openDetail(filtered, n),
                              ),
                            ),
                          ];
                        }).toList(),
                      ),
              ),
            ],
          );
        },
        loading: () => ListView.builder(
          padding: EdgeInsets.all(20.w),
          itemCount: 8,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: ShimmerBox(
              width: double.infinity,
              height: 50.h,
              borderRadius: 10.r,
            ),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.toString(), textAlign: TextAlign.center),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: () => ref.invalidate(islamicNamesNotifierProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderTab(String label, String value) {
    final selected = _genderFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _genderFilter = value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.emeraldInk : Colors.transparent,
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.sp,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
