import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/favorites/domain/entities/favorite_item.dart';
import '../../features/favorites/presentation/providers/favorites_providers.dart';
import 'islamic_ornaments.dart';

/// Favorite toggle styled to sit on a hero header.
class FavoriteGlassButton extends ConsumerWidget {
  final FavoriteItem item;
  const FavoriteGlassButton({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(item.id));
    return GlassIconButton(
      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onPressed: () =>
          ref.read(favoritesNotifierProvider.notifier).toggle(item),
    );
  }
}
