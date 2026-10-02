import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/islamic_name.dart';
import '../../domain/services/islamic_names_filter.dart';
import '../providers/islamic_names_providers.dart';
import '../widgets/gender_hero_card.dart';
import '../widgets/islamic_name_list_tile.dart';
import '../widgets/origin_filter_sheet.dart';
import 'islamic_name_detail_screen.dart';
import '../../../../shared/widgets/feature_hero.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';

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

  void _selectGender(String value) {
    setState(() => _genderFilter = _genderFilter == value ? 'all' : value);
  }

  void _openDetail(List<IslamicName> pool, IslamicName name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IslamicNameDetailScreen(name: name, pool: pool),
      ),
    );
  }

  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset / 140 : 0.0).clamp(
        0.0,
        1.0,
      );
      if (t != _bar.value) _bar.value = t;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final namesAsync = ref.watch(islamicNamesNotifierProvider);
    final all = namesAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(child: _hero(all)),
                ...namesAsync.when(
                  data: _content,
                  loading: () => [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 0),
                      sliver: SliverList.separated(
                        itemCount: 6,
                        separatorBuilder: (_, _) => SizedBox(height: 12.h),
                        itemBuilder: (_, _) => ShimmerBox(
                          width: double.infinity,
                          height: 84.h,
                          borderRadius: 22.r,
                        ),
                      ),
                    ),
                  ],
                  error: (error, _) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.w),
                        child: Column(
                          children: [
                            Text(error.toString(), textAlign: TextAlign.center),
                            SizedBox(height: 12.h),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.emeraldInk,
                              ),
                              onPressed: () =>
                                  ref.invalidate(islamicNamesNotifierProvider),
                              child: Text(
                                'Try again',
                                style: TextStyle(color: AppColors.onEmeraldInk),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 32.h,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(opacity: _bar, title: 'Islamic Names'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(List<IslamicName>? all) {
    final boys = all?.where((n) => n.gender == 'male').length ?? 0;
    final girls = all?.where((n) => n.gender == 'female').length ?? 0;
    return FeatureHero(
      title: 'Islamic Names',
      subtitle: 'Beautiful names with their meanings, for your little one.',
      ghostIcon: Icons.child_care_rounded,
      chips: [
        FeatureHeroChip(
          Icons.auto_awesome_rounded,
          '${all?.length ?? 0} names',
        ),
        FeatureHeroChip(Icons.male_rounded, '$boys boys'),
        FeatureHeroChip(Icons.female_rounded, '$girls girls'),
      ],
    );
  }

  List<Widget> _content(List<IslamicName> allNames) {
    final origins = IslamicNamesFilter.uniqueOrigins(allNames);
    final filtered = IslamicNamesFilter.apply(
      allNames,
      genderFilter: _genderFilter,
      originFilters: _originFilters,
      query: _query,
    );
    final grouped = IslamicNamesFilter.groupAlphabetically(filtered);
    final boyCount = allNames.where((n) => n.gender == 'male').length;
    final girlCount = allNames.where((n) => n.gender == 'female').length;

    var index = 0;
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: GenderHeroCard(
                  imagePath: 'assets/images/boy_name.png',
                  label: "Boys' Names",
                  count: boyCount,
                  accent: AppColors.boyAccent,
                  accentBg: AppColors.boyAccentBg,
                  selected: _genderFilter == 'male',
                  dimmed: _genderFilter == 'female',
                  onTap: () => _selectGender('male'),
                ).slideIn(RevealDirection.start),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child:
                    GenderHeroCard(
                      imagePath: 'assets/images/girl_name.jpeg',
                      label: "Girls' Names",
                      count: girlCount,
                      accent: AppColors.girlAccent,
                      accentBg: AppColors.girlAccentBg,
                      selected: _genderFilter == 'female',
                      dimmed: _genderFilter == 'male',
                      onTap: () => _selectGender('female'),
                    ).slideIn(
                      RevealDirection.end,
                      delay: const Duration(milliseconds: 60),
                    ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
        sliver: SliverToBoxAdapter(
          child:
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.inkText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name or meaning…',
                        hintStyle: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 20.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                        border: _fieldBorder(AppColors.borderWarm),
                        enabledBorder: _fieldBorder(AppColors.borderWarm),
                        focusedBorder: _fieldBorder(AppColors.emeraldInk, 1.5),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _OriginFilterButton(
                    count: _originFilters.length,
                    onTap: () async {
                      final result = await showOriginFilterSheet(
                        context,
                        allOrigins: origins,
                        initiallySelected: _originFilters,
                      );
                      if (result != null) {
                        setState(() => _originFilters = result);
                      }
                    },
                  ),
                ],
              ).slideIn(
                RevealDirection.bottom,
                delay: const Duration(milliseconds: 140),
              ),
        ),
      ),
      if (filtered.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(36.w, 56.h, 36.w, 0),
            child: Column(
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    color: AppColors.worshipAccentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 32.sp,
                    color: AppColors.worshipAccent,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'No names match your filters',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkText,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Try a different spelling, meaning or origin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ).slideIn(RevealDirection.bottom),
          ),
        )
      else
        for (final entry in grouped.entries) ...[
          // Same header as "Your groups": the letter in a tinted tile, a
          // count pill at the end.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 12.h),
              child: Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.worshipAccentBg,
                      borderRadius: BorderRadius.circular(11.r),
                    ),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.worshipAccent,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Names with ${entry.key}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.worshipAccentBg,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${entry.value.length}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.worshipAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            sliver: SliverList.separated(
              itemCount: entry.value.length,
              separatorBuilder: (_, _) => SizedBox(height: 10.h),
              itemBuilder: (context, i) {
                final name = entry.value[i];
                return IslamicNameListTile(
                  name: name,
                  onTap: () => _openDetail(filtered, name),
                ).slideInAt(index++ % 8);
              },
            ),
          ),
        ],
    ];
  }

  OutlineInputBorder _fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18.r),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _OriginFilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _OriginFilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return PressScale(
      scale: AppMotion.pressScaleSmall,
      child: Material(
        color: active ? AppColors.emeraldInk : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(18.r),
          onTap: onTap,
          child: Container(
            height: 50.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              border: active ? null : Border.all(color: AppColors.borderWarm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18.sp,
                  color: active
                      ? AppColors.onEmeraldInk
                      : AppColors.textSecondary,
                ),
                if (active) ...[
                  SizedBox(width: 6.w),
                  Text(
                    '$count',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onEmeraldInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
