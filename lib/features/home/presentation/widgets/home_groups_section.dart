import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../groups/domain/entities/group.dart';
import '../../../groups/presentation/providers/groups_providers.dart';
import '../../../groups/presentation/widgets/empty_groups.dart';
import '../../../groups/presentation/widgets/group_card.dart';
import '../../../groups/presentation/widgets/group_search_field.dart';

/// "Groups" on Home: create a group, search the ones you are in, and open
/// one. This is where the old Groups tab's list lives now.
///
/// It is a sliver for Home's scroll view, and the rows are built lazily, so
/// only the groups on screen are built (and load their live numbers).
///
/// Tapping the search field scrolls the section up under the pinned header
/// ([topInset] tall), so the field and the results stay clear of the keyboard.
class HomeGroupsSection extends ConsumerStatefulWidget {
  /// How much of the top of the screen the pinned header covers.
  final double topInset;

  const HomeGroupsSection({super.key, this.topInset = 0});

  @override
  ConsumerState<HomeGroupsSection> createState() => _HomeGroupsSectionState();
}

class _HomeGroupsSectionState extends ConsumerState<HomeGroupsSection> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  /// The heading, which the section scrolls to when search is tapped.
  final _anchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) _scrollUp();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Brings the heading to just under the pinned header, after the keyboard
  /// has started to open, so the results have the room.
  void _scrollUp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _anchor.currentContext;
      if (!mounted || anchor == null) return;
      final viewport = MediaQuery.sizeOf(context).height;
      Scrollable.ensureVisible(
        anchor,
        alignment: viewport <= 0 ? 0 : widget.topInset / viewport,
        duration: context.motion.duration(const Duration(milliseconds: 320)),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _create() async {
    HapticFeedback.selectionClick();
    // Groups need an account: send guests through Sign Up → OTP, then back
    // here signed in.
    if (!ref.read(authSessionProvider).isAuthenticated) {
      context.push('/signup?redirect=${Uri.encodeQueryComponent('/')}');
      return;
    }
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

    final groups = groupsAsync.valueOrNull;
    final shown = groups == null
        ? const <Group>[]
        : query.isEmpty
        ? groups
        : groups
              .where(
                (g) =>
                    g.name.toLowerCase().contains(query) ||
                    g.description.toLowerCase().contains(query),
              )
              .toList();

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  key: _anchor,
                  children: [
                    Expanded(
                      child: Text(
                        'Groups',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkText,
                        ),
                      ).slideIn(RevealDirection.bottomStart),
                    ),
                    Pressable(
                      onTap: _create,
                      scale: AppMotion.pressScaleSmall,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 6.h,
                          horizontal: 4.w,
                        ),
                        child: Text(
                          '+ New',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emeraldInk,
                          ),
                        ),
                      ),
                    ).slideIn(RevealDirection.topEnd, distance: 16),
                  ],
                ),

                GroupSearchField(controller: _search, focusNode: _searchFocus),
              ],
            ),
          ),
          if (groupsAsync.isLoading && groups == null)
            SliverList.builder(
              itemCount: 3,
              itemBuilder: (_, _) => Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: ShimmerBox(
                  width: double.infinity,
                  height: 72.h,
                  borderRadius: 18.r,
                ),
              ),
            )
          else if (groupsAsync.hasError && groups == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Column(
                  children: [
                    Text(
                      groupsAsync.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12.h),
                    FilledButton(
                      onPressed: () => ref.invalidate(myGroupsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else if (shown.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: EmptyGroups(
                  isSearching: query.isNotEmpty,
                  onCreateGroup: _create,
                ),
              ),
            )
          else
            SliverList.separated(
              itemCount: shown.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 1, color: AppColors.borderWarm),
              itemBuilder: (context, i) => GroupCard(
                // Keyed by group, so a row keeps its own live numbers when the
                // list is filtered or reordered.
                key: ValueKey(shown[i].id),
                group: shown[i],
                onTap: () => context.push('/groups/${shown[i].id}'),
              ).slideInAt(i),
            ),
        ],
      ),
    );
  }
}
