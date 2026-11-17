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
class HomeGroupsSection extends ConsumerStatefulWidget {
  const HomeGroupsSection({super.key});

  @override
  ConsumerState<HomeGroupsSection> createState() => _HomeGroupsSectionState();
}

class _HomeGroupsSectionState extends ConsumerState<HomeGroupsSection> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Groups',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkText,
                ),
              ).slideIn(RevealDirection.bottomStart),
            ),
            Pressable(
              onTap: _create,
              scale: AppMotion.pressScaleSmall,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                child: Text(
                  '+ New',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldInk,
                  ),
                ),
              ),
            ).slideIn(RevealDirection.topEnd, distance: 16),
          ],
        ),
        SizedBox(height: 14.h),
        GroupSearchField(controller: _search),
        SizedBox(height: 8.h),
        groupsAsync.when(
          data: (groups) => _list(groups, query),
          loading: () => Column(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 72.h,
                    borderRadius: 18.r,
                  ),
                ),
            ],
          ),
          error: (e, _) => Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Column(
              children: [
                Text(e.toString(), textAlign: TextAlign.center),
                SizedBox(height: 12.h),
                FilledButton(
                  onPressed: () => ref.invalidate(myGroupsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(List<Group> all, String query) {
    final groups = query.isEmpty
        ? all
        : all
              .where(
                (g) =>
                    g.name.toLowerCase().contains(query) ||
                    g.description.toLowerCase().contains(query),
              )
              .toList();

    if (groups.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 8.h),
        child: EmptyGroups(
          isSearching: query.isNotEmpty,
          onCreateGroup: _create,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: AppColors.borderWarm),
          GroupCard(
            group: groups[i],
            onTap: () => context.push('/groups/${groups[i].id}'),
          ).slideInAt(i),
        ],
      ],
    );
  }
}
