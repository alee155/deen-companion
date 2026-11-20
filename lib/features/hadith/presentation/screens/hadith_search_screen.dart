import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/providers/reading_preferences_provider.dart';
import '../../../../shared/widgets/failure_view.dart';
import '../../domain/entities/hadith.dart';
import '../../domain/hadith_search_topics.dart';
import '../providers/hadith_providers.dart';
import '../widgets/hadith_card_tile.dart';

/// Search across the hadith.
///
/// What it searches, and how, is told to the reader on the screen itself: the
/// English text of every hadith (including who narrated it), by word. Before
/// anything is typed it offers topics and narrators to try; when nothing is
/// found it says what to change.
class HadithSearchScreen extends ConsumerStatefulWidget {
  /// The book to start in, when opened from inside one.
  final String? currentCollection;
  const HadithSearchScreen({super.key, this.currentCollection});

  @override
  ConsumerState<HadithSearchScreen> createState() => _HadithSearchScreenState();
}

class _HadithSearchScreenState extends ConsumerState<HadithSearchScreen> {
  static const _minAutoSearchLength = 3;
  static const _autoSearchDelay = Duration(milliseconds: 700);

  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  /// The book searched, or null for all of them.
  late String? _collection = widget.currentCollection;

  /// False until the reader searches on this visit, so what an earlier visit
  /// left in the shared search state is never shown.
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    // Every visit starts empty. Providers can't be changed while the screen is
    // being built, so clear the old search just after.
    Future.microtask(() {
      if (!mounted || _searched) return;
      ref.read(hadithSearchNotifierProvider.notifier).search('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _runSearch([String? text]) {
    _debounce?.cancel();
    _searched = true;
    ref
        .read(hadithSearchNotifierProvider.notifier)
        .search(text ?? _controller.text, collection: _collection);
  }

  /// Search as the reader pauses typing, so they don't have to find the button.
  void _onChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _searched = true;
      ref.read(hadithSearchNotifierProvider.notifier).search('');
      return;
    }
    final isNumber =
        _collection != null && RegExp(r'^#?\d+$').hasMatch(trimmed);
    if (trimmed.length < _minAutoSearchLength && !isNumber) return;
    _debounce = Timer(_autoSearchDelay, _runSearch);
  }

  /// A suggestion was tapped: put it in the box and search straight away.
  void _searchFor(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.unfocus();
    _runSearch(text);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(hadithSearchNotifierProvider.notifier).search('');
    _focus.requestFocus();
  }

  void _setCollection(String? key) {
    if (key == _collection) return;
    setState(() => _collection = key);
    if (_controller.text.trim().isNotEmpty) _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(hadithSearchNotifierProvider);
    final info = ref.watch(hadithSearchInfoProvider);
    final isUrdu = ref.watch(
      readingPreferencesProvider.select((p) => p.isUrdu),
    );

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            _Header(
              controller: _controller,
              focus: _focus,
              hint: _collection != null
                  ? 'Word or hadith number, e.g. 2812'
                  : isUrdu
                  ? 'Search by word, e.g. fasting or روزہ'
                  : 'Search by word, e.g. fasting',
              selected: _collection,
              onChanged: _onChanged,
              onSubmitted: _runSearch,
              onClear: _clear,
              onBook: _setCollection,
            ),
            Expanded(child: _content(searchState, info, isUrdu)),
          ],
        ),
      ),
    );
  }

  Widget _content(
    AsyncValue<List<Hadith>?> searchState,
    HadithSearchInfo? info,
    bool isUrdu,
  ) {
    if (!_searched) return _Welcome(isUrdu: isUrdu, onPick: _searchFor);
    return searchState.when(
      loading: () => const _Searching(),
      error: (error, _) => FailureView(
        failure: failureFrom(error),
        onRetry: () async => _runSearch(),
      ),
      data: (results) {
        if (results == null || info == null && results.isEmpty) {
          return _Welcome(isUrdu: isUrdu, onPick: _searchFor);
        }
        if (results.isEmpty) {
          return _NoResults(
            info: info!,
            isUrdu: isUrdu,
            bookName: _collection == null
                ? null
                : _bookLabel(ref, _collection!),
            onPick: _searchFor,
            onSearchAllBooks:
                _collection == null || info.mode == HadithSearchMode.number
                ? null
                : () => _setCollection(null),
          );
        }
        return _Results(
          results: results,
          info: info,
          isUrdu: isUrdu,
          onOpen: (hadith) => context.push('/hadith/detail', extra: hadith),
        );
      },
    );
  }
}

/// The same green header as the Duas search: back button, a rounded search
/// field, and (here) the books to search in, as pills on the green.
class _Header extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final String? selected;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final ValueChanged<String?> onBook;

  const _Header({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.selected,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.heroGradient),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 0, 14.h),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(end: 16.w),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(child: _field()),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              _BookFilter(selected: selected, onSelected: onBook),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field() {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20.sp, color: AppColors.goldLight),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14.sp,
                  fontFamilyFallback: _urduFonts,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : Pressable(
                    scale: AppMotion.pressScaleSmall,
                    onTap: onClear,
                    child: Semantics(
                      button: true,
                      label: 'Clear',
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Urdu words that appear inside ordinary (Latin) text — the hint, a tip, a
/// label — are drawn in the same Nastaliq as the rest of the Urdu.
const _urduFonts = ['NotoNastaliqUrdu'];

/// A book's display name, from the loaded collections when there.
String _bookLabel(WidgetRef ref, String key) {
  final collections = ref.read(hadithCollectionsNotifierProvider).valueOrNull;
  for (final c in collections ?? const []) {
    if (c.key == key) return c.name;
  }
  return _fallbackBookNames[key] ?? key;
}

const _fallbackBookNames = {
  'bukhari': 'Sahih al-Bukhari',
  'muslim': 'Sahih Muslim',
  'abudawud': 'Sunan Abu Dawud',
  'tirmidhi': 'Jami at-Tirmidhi',
  'ibnmajah': 'Sunan Ibn Majah',
  'nasai': 'Sunan an-Nasa’i',
  'malik': 'Muwatta Malik',
  'nawawi': 'Forty Hadith of Nawawi',
  'qudsi': 'Forty Hadith Qudsi',
  'dehlawi': 'Forty Hadith of Shah Waliullah',
};

// ─────────────────────────────────────────────────────────────────────────
// Which book to search

class _BookFilter extends ConsumerWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _BookFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref
        .watch(hadithCollectionsNotifierProvider)
        .valueOrNull;
    final entries = collections != null && collections.isNotEmpty
        ? [for (final c in collections) (key: c.key, name: c.name)]
        : [
            for (final key in HadithSearchNotifier.allCollections)
              (key: key, name: _fallbackBookNames[key] ?? key),
          ];

    return SizedBox(
      height: 34.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(right: 16.w),
        children: [
          _Pill(
            label: 'All books',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final e in entries) ...[
            SizedBox(width: 8.w),
            _Pill(
              label: e.name,
              selected: selected == e.key,
              onTap: () => onSelected(e.key),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: AnimatedContainer(
          duration: context.motion.duration(AppMotion.fast),
          curve: AppMotion.entrance,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.emeraldInk : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Before anything is searched

class _Welcome extends StatelessWidget {
  final bool isUrdu;
  final ValueChanged<String> onPick;

  const _Welcome({required this.isUrdu, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 32.h),
      children: [
        const _IconBadge(icon: Icons.search_rounded),
        SizedBox(height: 14.h),
        Text(
          'Find a hadith',
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: AppColors.inkText),
        ),
        SizedBox(height: 8.h),
        Text(
          'Type a word or a topic. The search reads the English translation '
          'of every hadith, including who narrated it.'
          '${isUrdu ? ' Results are shown in Urdu.' : ''}',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: 22.h),
        _SectionLabel(isUrdu ? 'TRY A TOPIC  ·  موضوع' : 'TRY A TOPIC'),
        SizedBox(height: 10.h),
        _TopicChips(isUrdu: isUrdu, onPick: onPick),
        SizedBox(height: 20.h),
        const _SectionLabel('OR A NARRATOR'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final name in HadithSearchTopics.narrators)
              _Suggestion(label: name, onTap: () => onPick(name)),
          ],
        ).slideIn(RevealDirection.bottom, distance: 10),
        SizedBox(height: 22.h),
        _Tips(isUrdu: isUrdu),
      ],
    );
  }
}

class _TopicChips extends StatelessWidget {
  final bool isUrdu;
  final ValueChanged<String> onPick;

  const _TopicChips({required this.isUrdu, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final topic in HadithSearchTopics.featured)
          // An Urdu reader sees the topics in Urdu; tapping one searches it
          // (the search turns the Urdu word into its English one).
          _Suggestion(
            label: isUrdu ? topic.urdu : topic.englishLabel,
            urdu: isUrdu,
            onTap: () => onPick(isUrdu ? topic.urdu : topic.english),
          ),
      ],
    ).slideIn(RevealDirection.bottom, distance: 10);
  }
}

class _Tips extends StatelessWidget {
  final bool isUrdu;
  const _Tips({required this.isUrdu});

  @override
  Widget build(BuildContext context) {
    final tips = [
      (
        Icons.short_text_rounded,
        'One or two keywords work best, like “charity” or “prayer fasting”.',
      ),
      (
        Icons.shuffle_rounded,
        'Several words are found in any order, as long as a hadith has them all.',
      ),
      (Icons.menu_book_outlined, 'Pick a book above to search only inside it.'),
      (
        Icons.tag_rounded,
        'With a book picked, type a hadith number, like 2812 in Sahih al-Bukhari.',
      ),
      if (isUrdu)
        (
          Icons.translate_rounded,
          'You can type common topics in Urdu too, like نماز or روزہ.',
        ),
    ];
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderWarm),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tips.length; i++) ...[
            if (i > 0) SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(tips[i].$1, size: 18.sp, color: AppColors.emeraldInk),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    tips[i].$2,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                      fontFamilyFallback: _urduFonts,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Searching, results, and nothing found

class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.emeraldInk),
          SizedBox(height: 14.h),
          Text(
            'Searching…',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  final List<Hadith> results;
  final HadithSearchInfo? info;
  final bool isUrdu;
  final ValueChanged<Hadith> onOpen;

  const _Results({
    required this.results,
    required this.info,
    required this.isUrdu,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final query = info?.query;
    final notes = <String>[
      if (query != null && query.translatedFromUrdu)
        'Searched the English translation for “${query.term}”.',
      if (info?.mode == HadithSearchMode.allWords)
        'No hadith has these words together as a phrase, so these are hadith '
            'that contain all of them.',
      if (info?.mayHaveMore ?? false)
        info?.collection == null
            ? 'Showing the top results from each book. Pick a book above to '
                  'see more from it.'
            : 'Showing the first results. Try a more specific word to narrow '
                  'them down.',
    ];

    return ListView.builder(
      padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.hadithAccentBg,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        info?.mode == HadithSearchMode.number
                            ? '#${query?.number}'
                            : '${results.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.hadithAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        info?.mode == HadithSearchMode.number
                            ? 'Hadith found'
                            : 'hadith'
                                  '${query == null ? '' : ' for “${query.typed}”'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.inkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldInk.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: AppColors.emeraldInk.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16.sp,
                          color: AppColors.emeraldInk,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            notes.join(' '),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        final hadith = results[index - 1];
        return HadithCardTile(
          hadith: hadith,
          highlight: info?.mode == HadithSearchMode.number
              ? const []
              : query?.words ?? const [],
          onTap: () => onOpen(hadith),
        ).slideInAt(index - 1);
      },
    );
  }
}

class _NoResults extends StatelessWidget {
  final HadithSearchInfo info;
  final bool isUrdu;
  final String? bookName;
  final ValueChanged<String> onPick;
  final VoidCallback? onSearchAllBooks;

  const _NoResults({
    required this.info,
    required this.isUrdu,
    required this.bookName,
    required this.onPick,
    required this.onSearchAllBooks,
  });

  @override
  Widget build(BuildContext context) {
    // Typed in Urdu/Arabic and nothing in it was a topic we know.
    final unreadable = !info.query.isSearchable;

    final isNumber = info.mode == HadithSearchMode.number;
    final title = isNumber
        ? 'No hadith numbered ${info.query.number}'
              '${bookName == null ? '' : ' in $bookName'}'
        : unreadable
        ? 'That word can’t be searched yet'
        : 'No hadith found for “${info.query.typed}”'
              '${bookName == null ? '' : ' in $bookName'}';
    final lead = isNumber
        ? 'That book has no hadith with this number. Here is what to try:'
        : unreadable
        ? 'Hadith search reads the English translation, so it needs English '
              'words. These topics also work in Urdu:'
        : 'Here is what to try:';
    final suggestions = <String>[
      if (isNumber) ...[
        'Check the number: each book is numbered on its own.',
        'Pick another book, or clear the box to search by word.',
      ] else if (!unreadable) ...[
        'Check the spelling.',
        'Use one keyword instead of a sentence.',
        'Use English words: that is the text that is searched.',
        'Try part of a name, like “Hurair” for Abu Hurairah.',
      ],
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 32.h),
      children: [
        const _IconBadge(icon: Icons.search_off_rounded),
        SizedBox(height: 14.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: AppColors.inkText),
        ),
        SizedBox(height: 8.h),
        Text(
          lead,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          SizedBox(height: 14.h),
          for (final s in suggestions)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 7.h),
                    child: Icon(
                      Icons.circle,
                      size: 5.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      s,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (onSearchAllBooks != null) ...[
          SizedBox(height: 10.h),
          Center(
            child: OutlinedButton.icon(
              onPressed: onSearchAllBooks,
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('Search all books'),
            ),
          ),
        ],
        SizedBox(height: 22.h),
        _SectionLabel(isUrdu ? 'TRY A TOPIC  ·  موضوع' : 'TRY A TOPIC'),
        SizedBox(height: 10.h),
        _TopicChips(isUrdu: isUrdu, onPick: onPick),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Small pieces

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          color: AppColors.emeraldInk.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 30.sp, color: AppColors.emeraldInk),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        fontFamilyFallback: _urduFonts,
      ),
    );
  }
}

/// A tappable example search.
class _Suggestion extends StatelessWidget {
  final String label;
  final bool urdu;
  final VoidCallback onTap;

  const _Suggestion({
    required this.label,
    required this.onTap,
    this.urdu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: Semantics(
        button: true,
        label: 'Search for $label',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: urdu ? 2.h : 8.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderWarm),
          ),
          child: Text(
            label,
            style: urdu
                ? TextStyle(
                    fontFamily: 'NotoNastaliqUrdu',
                    fontSize: 16.sp,
                    height: 2.0,
                    color: AppColors.inkText,
                  )
                : AppTypography.bodyMedium.copyWith(
                    color: AppColors.inkText,
                    fontWeight: FontWeight.w600,
                  ),
          ),
        ),
      ),
    );
  }
}
