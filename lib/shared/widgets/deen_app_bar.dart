import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// The app's one app bar.
///
/// Screens used to each hand-roll an `AppBar` with their own background,
/// foreground, elevation and title style, which is why the top of the app
/// looked different depending on where you were. This centralises all of it:
/// same height, same title treatment, same back affordance, and a single
/// `transparent` variant for the screens that paint their own gradient behind
/// the bar.
///
/// Back navigation goes through GoRouter's `pop` when there is something to
/// pop, and falls back to the Home tab otherwise — a screen opened directly
/// (from a deep link, or as the first route after a redirect) can't be left
/// with a dead back button.
class DeenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Optional second line — context that doesn't belong in the title.
  final String? subtitle;

  /// Replaces the title text entirely — for the search screens, whose "title"
  /// is a text field. They still get the same bar chrome and back button.
  final Widget? titleWidget;

  final List<Widget>? actions;

  /// Draws no background, for screens with their own gradient body. Pair with
  /// `extendBodyBehindAppBar: true`.
  final bool transparent;

  /// Overrides automatic detection — pass false to hide the back button on a
  /// screen that is a tab root.
  final bool? showBack;

  final Widget? bottom;

  const DeenAppBar({
    super.key,
    this.title = '',
    this.subtitle,
    this.titleWidget,
    this.actions,
    this.transparent = false,
    this.showBack,
    this.bottom,
  });

  static const double _height = 56;
  static const double _bottomHeight = 48;

  @override
  Size get preferredSize =>
      Size.fromHeight(_height + (bottom == null ? 0 : _bottomHeight));

  bool _canPop(BuildContext context) {
    if (showBack != null) return showBack!;
    return Navigator.of(context).canPop() || GoRouter.of(context).canPop();
  }

  void _onBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      // Nothing to go back to — land on Home rather than nowhere.
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBackButton = _canPop(context);

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: transparent
          ? Colors.transparent
          : AppColors.surfaceLight,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.inkText,
      centerTitle: false,
      titleSpacing: showBackButton ? 0 : 20.w,
      toolbarHeight: _height,
      leading: showBackButton
          ? IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppColors.inkText),
              tooltip: 'Back',
              onPressed: () => _onBack(context),
            )
          : null,
      title:
          titleWidget ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headline.copyWith(
                  color: AppColors.inkText,
                  fontSize: 17.sp,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
      actions: [
        ...?actions,
        SizedBox(width: 4.w),
      ],
      bottom: bottom == null
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(_bottomHeight),
              child: bottom!,
            ),
      shape: transparent
          ? null
          : Border(bottom: BorderSide(color: AppColors.borderWarm)),
    );
  }
}
