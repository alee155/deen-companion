import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/dua_category.dart';
import '../providers/dua_providers.dart';
import '../widgets/dua_card_tile.dart';

class DuaCategoryScreen extends ConsumerWidget {
  final DuaCategory category;
  const DuaCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filters the already-cached bundle — no network call happens here.
    final bundleAsync = ref.watch(duasBundleNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: Text(category.name),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: bundleAsync.when(
        data: (bundle) {
          final duas = bundle.byCategory(category.id);
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: duas.length,
            itemBuilder: (context, index) => DuaCardTile(dua: duas[index]),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.emeraldInk),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
