import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/realtime_providers.dart';
import '../providers/realtime_service.dart';

/// A small "Live / Reconnecting / Offline" marker. Delivery is best effort,
/// so this says what the connection is doing, not that nothing was missed.
class LiveStatusChip extends ConsumerWidget {
  const LiveStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(liveStatusProvider);
    final (label, color) = switch (status) {
      LiveStatus.live => ('Live', const Color(0xFF22C55E)),
      LiveStatus.connecting ||
      LiveStatus.reconnecting => ('Reconnecting', AppColors.amber),
      LiveStatus.offline ||
      LiveStatus.unauthorized => ('Offline', AppColors.textSecondary),
    };
    return Semantics(
      label: 'Live updates: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
