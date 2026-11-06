import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/delete_account_controller.dart';
import '../../../groups/presentation/widgets/group_sheet_widgets.dart';

/// Asks for the last confirmation before deleting the account. Resolves true
/// once the account is gone; Cancel, close or a swipe down resolve null.
Future<bool?> showDeleteAccountSheet(BuildContext context) =>
    showGroupSheet<bool>(context, (_) => const DeleteAccountSheet());

class DeleteAccountSheet extends ConsumerWidget {
  /// Opens [AppConstants.deleteAccountUrl]. Tests replace it.
  final Future<void> Function(String url)? onOpenLink;

  const DeleteAccountSheet({super.key, this.onOpenLink});

  Future<void> _openLink(String url) async {
    final custom = onOpenLink;
    if (custom != null) return custom(url);
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final navigator = Navigator.of(context);
    final deleted = await ref
        .read(deleteAccountControllerProvider.notifier)
        .delete();
    if (deleted && navigator.mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deleteAccountControllerProvider);
    return PopScope(
      canPop: !state.isDeleting,
      child: GroupSheetFrame(
        destructive: true,
        icon: Icons.delete_forever_rounded,
        title: 'Delete account?',
        subtitle: 'This can’t be undone.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Point(
              icon: Icons.person_off_outlined,
              color: AppColors.error,
              text: 'Your account is permanently deleted.',
            ),
            SizedBox(height: 10.h),
            _Point(
              icon: Icons.phone_iphone_rounded,
              color: AppColors.emeraldInk,
              text: 'Favorites and settings on this device are kept.',
            ),
            SizedBox(height: 10.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openLink(AppConstants.deleteAccountUrl),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Text(
                  'See what is deleted and what is kept',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldInk,
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            SheetNotice(message: state.errorMessage),
            SheetButton(
              label: 'Delete my account',
              icon: Icons.delete_outline_rounded,
              destructive: true,
              loading: state.isDeleting,
              onPressed: () => _delete(context, ref),
            ),
            SizedBox(height: 10.h),
            SheetSecondaryButton(
              label: 'Cancel',
              onPressed: state.isDeleting
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Point({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.sp, color: color),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
