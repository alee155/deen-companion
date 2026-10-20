import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/favorite_item.dart';

/// One favorite as a card: category badge, title, subtitle, when it was saved.
/// Swipe left to remove, tap to open, or tap the heart, which plays a brief
/// un-fill before removing (removal always goes through the caller's
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
    final radius = BorderRadius.circular(20.r);
    final meta = 'Saved ${favoriteSavedLabel(item.savedAt)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
      child: Dismissible(
        key: ValueKey('dismiss_${item.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => widget.onRemove(),
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: radius,
          ),
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 24.w),
          child: Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 24.sp,
          ),
        ),
        child: AnimatedOpacity(
          duration: context.motion.duration(AppMotion.normal),
          curve: AppMotion.entrance,
          opacity: _removing ? 0 : 1,
          child: PressScale(
            child: Material(
              color: AppColors.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(color: AppColors.borderWarm),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 6.w, 12.h),
                  child: Row(
                    children: [
                      _Badge(icon: widget.icon, asset: widget.iconAsset),
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
                                fontWeight: FontWeight.w700,
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
                              meta,
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
                          padding: EdgeInsets.all(10.w),
                          child: IconSwap(
                            child: Icon(
                              _removing
                                  ? Icons.favorite_border_rounded
                                  : Icons.favorite_rounded,
                              key: ValueKey(_removing),
                              color: AppColors.emeraldInk,
                              size: 22.sp,
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
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String? asset;
  const _Badge({required this.icon, required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      width: 48.h,
      alignment: Alignment.center,
      padding: asset != null ? EdgeInsets.all(9.w) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: asset != null
            ? AppColors.parchment
            : AppColors.emeraldInk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: asset != null
          ? Image.asset(asset!, fit: BoxFit.contain)
          : Icon(icon, color: AppColors.emeraldInk, size: 22.sp),
    );
  }
}

/// "Just now", "5m ago", "3d ago", or the date once it is over a week old.
String favoriteSavedLabel(DateTime date, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return 'just now';
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
