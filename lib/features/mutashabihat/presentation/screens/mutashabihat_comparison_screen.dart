import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/mutashabihat_entry.dart';
import '../widgets/mutashabihat_base_verse_card.dart';
import '../widgets/mutashabihat_similar_verse_card.dart';

class MutashabihatComparisonScreen extends StatefulWidget {
  final MutashabihatEntry entry;
  final VoidCallback? onNext; // only wired for random-practice mode

  const MutashabihatComparisonScreen({
    super.key,
    required this.entry,
    this.onNext,
  });

  @override
  State<MutashabihatComparisonScreen> createState() =>
      _MutashabihatComparisonScreenState();
}

class _MutashabihatComparisonScreenState
    extends State<MutashabihatComparisonScreen> {
  bool _quizMode = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        title: const Text('Compare Verses'),
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.inkText,
      ),
      body: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          MutashabihatBaseVerseCard(verse: widget.entry.verse),
          SizedBox(height: 12.h),
          CheckboxListTile(
            value: _quizMode,
            onChanged: (v) => setState(() => _quizMode = v ?? true),
            activeColor: AppColors.quranAccent,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Quiz mode — hide similar verses until I reveal them',
            ),
          ),
          Text(
            '${widget.entry.similarVerses.length} similar verse${widget.entry.similarVerses.length == 1 ? '' : 's'} found elsewhere in the Quran',
            style: TextStyle(fontSize: 12.sp, color: AppColors.textMuted),
          ),
          ...widget.entry.similarVerses.map(
            (v) =>
                MutashabihatSimilarVerseCard(verse: v, startHidden: _quizMode),
          ),
          if (widget.onNext != null) ...[
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onNext,
                child: const Text('Next random pair'),
              ),
            ),
          ],
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
