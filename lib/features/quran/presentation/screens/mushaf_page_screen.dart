import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/quran_providers.dart';

class MushafPageScreen extends ConsumerStatefulWidget {
  final int initialPage;
  const MushafPageScreen({super.key, this.initialPage = 1});

  @override
  ConsumerState<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends ConsumerState<MushafPageScreen> {
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(mushafPageNotifierProvider(_currentPage));

    return Scaffold(
      appBar: AppBar(
        title: Text('Page $_currentPage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < 604
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
      body: pageAsync.when(
        data: (page) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: page.wordsByLine.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Wrap(
                alignment: WrapAlignment.center,
                textDirection: TextDirection.rtl,
                children: entry.value
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          w.textUthmani,
                          style: const TextStyle(fontSize: 22, height: 2),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }).toList(),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
      ),
    );
  }
}
