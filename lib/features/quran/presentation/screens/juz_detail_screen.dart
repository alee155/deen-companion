import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quran_providers.dart';
import '../widgets/juz_verse_tile.dart';

class JuzDetailScreen extends ConsumerWidget {
  final int juzNumber;
  const JuzDetailScreen({super.key, required this.juzNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzAsync = ref.watch(juzNotifierProvider(juzNumber));

    return Scaffold(
      appBar: AppBar(title: Text('Juz $juzNumber')),
      body: juzAsync.when(
        data: (juz) => ListView.separated(
          itemCount: juz.verses.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              JuzVerseTile(verse: juz.verses[index]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString()),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(juzNotifierProvider(juzNumber).notifier).refresh(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
