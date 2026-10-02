import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/motion/motion.dart';
import '../../../../shared/widgets/islamic_ornaments.dart';
import '../../../../shared/widgets/pinned_hero_bar.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../domain/entities/group.dart';
import '../providers/groups_providers.dart';
import '../widgets/empty_groups.dart';
import '../widgets/group_card.dart';
import '../widgets/group_search_field.dart';

/// Bottom-tab root for Groups. Create/Streak are pushed as top-level routes
/// (see app_router) so the bottom navigation bar isn't shown on them.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _bar = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
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
    _search.dispose();
    _scroll.dispose();
    _bar.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    HapticFeedback.selectionClick();
    final created = await context.push<Group>('/groups/create');
    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Text('“${created.name}” created'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(myGroupsProvider);
    final query = _search.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: 90.h,
              onRefresh: () async => ref.invalidate(myGroupsProvider),
              child: CustomScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _hero(groupsAsync.valueOrNull)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                    sliver: SliverToBoxAdapter(
                      child: GroupSearchField(controller: _search),
                    ),
                  ),
                  ...groupsAsync.when(
                    data: (groups) => _list(groups, query),
                    loading: () => [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                        sliver: SliverList.separated(
                          itemCount: 3,
                          separatorBuilder: (_, _) => SizedBox(height: 12.h),
                          itemBuilder: (_, _) => ShimmerBox(
                            width: double.infinity,
                            height: 96.h,
                            borderRadius: 22.r,
                          ),
                        ),
                      ),
                    ],
                    error: (e, _) => [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(32.w),
                          child: Column(
                            children: [
                              Text(e.toString(), textAlign: TextAlign.center),
                              SizedBox(height: 12.h),
                              FilledButton(
                                onPressed: () =>
                                    ref.invalidate(myGroupsProvider),
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Clears the floating bottom navigation bar.
                  SliverToBoxAdapter(child: SizedBox(height: 130.h)),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: PinnedHeroBar(
                opacity: _bar,
                title: 'Groups',
                showBack: false,
                trailingIcon: Icons.add_rounded,
                trailingTooltip: 'Create group',
                onTrailing: _create,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _list(List<Group> all, String query) {
    final groups = query.isEmpty
        ? all
        : all
              .where(
                (g) =>
                    g.name.toLowerCase().contains(query) ||
                    g.description.toLowerCase().contains(query),
              )
              .toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 12.h),
          child: Row(
            children: [
              Expanded(
                child:
                    Text(
                      'Your groups',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkText,
                      ),
                    ).slideIn(
                      RevealDirection.bottomStart,
                      delay: const Duration(milliseconds: 140),
                    ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.worshipAccentBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${groups.length}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.worshipAccent,
                  ),
                ),
              ).slideIn(
                RevealDirection.topEnd,
                delay: const Duration(milliseconds: 190),
                duration: AppMotion.normal,
                distance: 16,
              ),
            ],
          ),
        ),
      ),
      if (groups.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: EmptyGroups(
              isSearching: query.isNotEmpty,
              onCreateGroup: _create,
            ),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverList.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (context, i) => GroupCard(
              group: groups[i],
              onTap: () => context.push('/groups/${groups[i].id}/streak'),
            ).slideInAt(i),
          ),
        ),
    ];
  }

  Widget _hero(List<Group>? groups) {
    final total = groups?.length ?? 0;
    final owned = groups?.where((g) => g.isOwner).length ?? 0;
    Widget chip(IconData icon, String text, RevealDirection dir, int ms) =>
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14.sp, color: AppColors.goldLight),
              SizedBox(width: 6.w),
              Text(
                text,
                style: TextStyle(fontSize: 12.sp, color: Colors.white),
              ),
            ],
          ),
        ).slideIn(
          dir,
          delay: Duration(milliseconds: ms),
          duration: AppMotion.normal,
          distance: 18,
        );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroSurface, AppColors.emeraldInkDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GeometricPattern(
              color: AppColors.goldLight.withValues(alpha: 0.08),
              cell: 52,
            ),
          ),
          Positioned(
            right: -24.w,
            top: 40.h,
            child: Icon(
              Icons.groups_rounded,
              size: 170.sp,
              color: AppColors.gold.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              MediaQuery.of(context).padding.top + 66.h,
              24.w,
              26.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quran Groups',
                  style: TextStyle(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ).slideIn(RevealDirection.topStart),
                SizedBox(height: 6.h),
                Text(
                  'Read, learn and stay consistent with your community.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.45,
                    color: AppColors.onHeroSurface.withValues(alpha: 0.78),
                  ),
                ).slideIn(
                  RevealDirection.start,
                  delay: const Duration(milliseconds: 70),
                ),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    chip(
                      Icons.groups_rounded,
                      '$total ${total == 1 ? 'group' : 'groups'}',
                      RevealDirection.bottomStart,
                      130,
                    ),
                    chip(
                      Icons.workspace_premium_rounded,
                      '$owned created by you',
                      RevealDirection.bottomEnd,
                      180,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
