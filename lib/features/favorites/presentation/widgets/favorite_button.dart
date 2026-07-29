import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/favorite_item.dart';
import '../providers/favorites_providers.dart';

/// A small heart icon button that reflects and toggles whether [item] is
/// favorited. Drop this into any content tile or detail header — it wires
/// itself up to the shared favorites store, no per-screen state needed.
class FavoriteButton extends ConsumerWidget {
  final FavoriteItem item;
  final double size;

  const FavoriteButton({super.key, required this.item, this.size = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(item.id));

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? AppColors.hadithAccent : AppColors.textMuted,
        size: size.sp,
      ),
      onPressed: () => ref.read(favoritesNotifierProvider.notifier).toggle(item),
    );
  }
}
