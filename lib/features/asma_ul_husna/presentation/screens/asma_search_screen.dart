import 'package:deen_companion/core/motion/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/asma_ul_husna_providers.dart';
import '../screens/asma_detail_screen.dart';
import '../widgets/asma_name_tile.dart';
import '../../../../shared/widgets/deen_app_bar.dart';

class AsmaSearchScreen extends ConsumerStatefulWidget {
  const AsmaSearchScreen({super.key});

  @override
  ConsumerState<AsmaSearchScreen> createState() => _AsmaSearchScreenState();
}

class _AsmaSearchScreenState extends ConsumerState<AsmaSearchScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(asmaSearchNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: DeenAppBar(
        titleWidget: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search by meaning…',
            border: InputBorder.none,
          ),
          onSubmitted: (q) =>
              ref.read(asmaSearchNotifierProvider.notifier).search(q),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => ref
                .read(asmaSearchNotifierProvider.notifier)
                .search(_controller.text),
          ),
        ],
      ),
      body: searchState.when(
        data: (results) {
          if (results == null)
            return Center(
              child: Text(
                'Try "merciful", "king", or "light".',
              ).slideIn(RevealDirection.bottom),
            );
          if (results.isEmpty)
            return Center(
              child: const Text(
                'No names found.',
              ).slideIn(RevealDirection.bottom),
            );
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) => AsmaNameTile(
              name: results[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AsmaDetailScreen(names: results, initialIndex: index),
                ),
              ),
            ).slideInAt(index, columns: 3, distance: 16),
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
