import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/quran_providers.dart';
import '../widgets/search_result_tile.dart';

class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key});

  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(quranSearchNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search the Quran…',
            border: InputBorder.none,
          ),
          onSubmitted: (query) =>
              ref.read(quranSearchNotifierProvider.notifier).search(query),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => ref
                .read(quranSearchNotifierProvider.notifier)
                .search(_controller.text),
          ),
        ],
      ),
      body: searchState.when(
        data: (results) {
          if (results == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Search across every translation and transliteration.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (results.isEmpty) {
            return const Center(child: Text('No verses found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            itemCount: results.length,
            itemBuilder: (context, index) =>
                SearchResultTile(result: results[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
