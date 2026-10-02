import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/favorite_item.dart';

/// A single row in the Favorites list: swipe-to-dismiss, tap to open, and a
/// heart button that plays a brief un-fill animation before actually
/// removing the item (the removal itself always goes through the caller's
/// [onRemove], never a local-only state change).
class FavoriteRow extends StatefulWidget {
  final FavoriteItem item;
  final IconData icon;

  /// The same illustrated icon Explore uses for this item's category, when
  /// one exists — takes priority over [icon] so a favorite's badge matches
  /// the icon the user already recognises from Explore.
  final String? iconAsset;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const FavoriteRow({
    super.key,
    required this.item,
    required this.icon,
    this.iconAsset,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<FavoriteRow> createState() => _FavoriteRowState();
}

class _FavoriteRowState extends State<FavoriteRow> {
  bool _removing = false;

  Future<void> _removeWithAnimation() async {
    setState(() => _removing = true);
    await Future.delayed(context.motion.duration(AppMotion.normal));
    if (mounted) widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onRemove(),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        child: Icon(
          Icons.delete_outline_rounded,
          color: AppColors.onEmeraldInk,
          size: 24.sp,
        ),
      ),
      child: AnimatedOpacity(
        duration: context.motion.duration(AppMotion.normal),
        curve: AppMotion.entrance,
        opacity: _removing ? 0 : 1,
        child: PressScale(
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              color: AppColors.parchment,
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    height: 46.h,
                    width: 46.h,
                    alignment: Alignment.center,
                    padding: widget.iconAsset != null
                        ? EdgeInsets.all(9.w)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: widget.iconAsset != null
                          ? AppColors.surfaceLight
                          : AppColors.inkText,
                      borderRadius: BorderRadius.circular(14.r),
                      border: widget.iconAsset != null
                          ? Border.all(
                              color: AppColors.borderWarm,
                              width: 1.2.w,
                            )
                          : null,
                    ),
                    child: widget.iconAsset != null
                        ? Image.asset(widget.iconAsset!, fit: BoxFit.contain)
                        : Icon(
                            widget.icon,
                            color: AppColors.emeraldInk,
                            size: 22.sp,
                          ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkText,
                          ),
                        ),
                        if (item.subtitle != null) ...[
                          SizedBox(height: 3.h),
                          Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        SizedBox(height: 4.h),
                        Text(
                          '${item.type.label} · ${_savedLabel(item.savedAt)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: _removeWithAnimation,
                    haptic: true,
                    scale: AppMotion.pressScaleSmall,
                    child: Padding(
                      padding: EdgeInsets.all(8.w),
                      child: IconSwap(
                        child: Icon(
                          _removing
                              ? Icons.favorite_border_rounded
                              : Icons.favorite_rounded,
                          key: ValueKey(_removing),
                          color: AppColors.emeraldInk,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _savedLabel(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
