import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../prayer_times/domain/entities/prayer_times.dart';
import '../../../prayer_times/presentation/widgets/prayer_hero.dart'
    show prayerLabels, prayerIcons;
import '../../domain/dnd_settings.dart';
import '../providers/prayer_dnd_provider.dart';

/// Text on the orange "selected" fill; dark for contrast on amber.
const _onSelected = Color(0xFF2A1608);

String formatDndMinutes(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return h == 1 ? '1 hour' : '$h hours';
  return '$h h $m min';
}

String _time(DateTime t) => DateFormat.jm().format(t);

/// "How long should it stay on?": Fixed (preset pills per prayer) or Custom
/// (slider per prayer). Both edit the same per-prayer durations.
class DndDurationSection extends ConsumerWidget {
  /// Called after any change so the native schedule is re-armed.
  final Future<void> Function() onChanged;

  const DndDurationSection({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dndSettingsProvider);
    final notifier = ref.read(dndSettingsProvider.notifier);
    final times = ref.watch(dndUpcomingTimesProvider).valueOrNull ?? const {};

    Future<void> chooseMode(DndDurationMode mode) async {
      HapticFeedback.selectionClick();
      await notifier.setMode(mode);
    }

    Future<void> set(PrayerName prayer, int minutes) async {
      await notifier.setDuration(prayer, minutes);
      await onChanged();
    }

    Future<void> clear(PrayerName prayer) async {
      await notifier.clearDuration(prayer);
      await onChanged();
    }

    Future<void> setAll(int minutes) async {
      await notifier.setAllDurations(minutes);
      await onChanged();
    }

    Future<void> clearAll() async {
      await notifier.clearAllDurations();
      await onChanged();
    }

    return Column(
      children: [
        _ModeCard(
          selected: settings.mode == DndDurationMode.preset,
          dir: RevealDirection.end,
          icon: Icons.hourglass_bottom_rounded,
          title: 'Fixed duration',
          subtitle: 'Pick a set time for each prayer',
          onTap: () => chooseMode(DndDurationMode.preset),
          body: _FixedBody(
            settings: settings,
            times: times,
            onSet: set,
            onClear: clear,
            onSetAll: setAll,
            onClearAll: clearAll,
          ),
        ),
        SizedBox(height: 10.h),
        _ModeCard(
          selected: settings.mode == DndDurationMode.custom,
          dir: RevealDirection.bottomStart,
          icon: Icons.tune_rounded,
          title: 'Custom duration',
          subtitle: 'Slide to choose up to 2 hours per prayer',
          onTap: () => chooseMode(DndDurationMode.custom),
          body: _CustomBody(
            settings: settings,
            times: times,
            onSet: set,
            onSetAll: setAll,
            onClear: clear,
          ),
        ),
      ],
    );
  }
}

// ── Mode card (same look as before; orange when selected) ───────────────

class _ModeCard extends StatelessWidget {
  final bool selected;
  final RevealDirection dir;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget body;

  const _ModeCard({
    required this.selected,
    required this.dir,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.normal),
      curve: AppMotion.entrance,
      decoration: BoxDecoration(
        color: selected ? AppColors.toolsAccentBg : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: selected ? AppColors.amber : AppColors.borderWarm,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          PressScale(
            child: InkWell(
              borderRadius: BorderRadius.circular(22.r),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: context.motion.duration(AppMotion.fast),
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.heroSurface
                            : AppColors.parchment,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        icon,
                        size: 21.sp,
                        color: selected ? AppColors.amber : AppColors.textMuted,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkText,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconSwap(
                      child: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        key: ValueKey(selected),
                        color: selected ? AppColors.amber : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ExpandSection(
            expanded: selected,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: SizedBox(width: double.infinity, child: body),
            ),
          ),
        ],
      ),
    ).slideIn(dir, onVisible: true);
  }
}

// ── Shared bits ─────────────────────────────────────────────────────────

class _PrayerBadge extends StatelessWidget {
  final PrayerName prayer;
  final bool configured;
  const _PrayerBadge({required this.prayer, required this.configured});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: context.motion.duration(AppMotion.fast),
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: configured
            ? AppColors.amber.withValues(alpha: 0.18)
            : AppColors.parchment,
        border: Border.all(
          color: configured ? AppColors.amber : AppColors.borderWarm,
        ),
      ),
      child: Icon(
        prayerIcons[prayer],
        size: 18.sp,
        color: configured ? AppColors.amberDeep : AppColors.textMuted,
      ),
    );
  }
}

/// Selectable duration container. Orange when selected.
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
      haptic: true,
      scale: AppMotion.pressScaleSmall,
      child: AnimatedContainer(
        duration: context.motion.duration(AppMotion.fast),
        curve: AppMotion.entrance,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : AppColors.parchment,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? AppColors.amberDeep : AppColors.borderWarm,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: selected ? _onSelected : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final PrayerName prayer;
  final VoidCallback onTap;
  const _RemoveButton({required this.prayer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: AppMotion.pressScaleSmall,
      semanticLabel: 'Remove ${prayerLabels[prayer]} duration',
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Icon(
          Icons.delete_outline_rounded,
          size: 20.sp,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Shared compact accordion (Fixed + Custom) ──────────────────────────

/// One compact row per prayer — badge, name, upcoming time and the saved
/// duration with "until" time — that expands to an editor. Used by both
/// Fixed and Custom so the two cards look and behave the same.
class _PrayerAccordion extends StatefulWidget {
  final DndSettings settings;
  final Map<PrayerName, DateTime> times;
  final void Function(PrayerName) onClear;

  /// Editor shown under a prayer. `close` collapses the row.
  final Widget Function(PrayerName prayer, VoidCallback close) editorFor;

  /// Optional first row that edits every prayer at once (Fixed only).
  final Widget Function(VoidCallback close)? allEditor;
  final int? allValue;

  const _PrayerAccordion({
    required this.settings,
    required this.times,
    required this.onClear,
    required this.editorFor,
    this.allEditor,
    this.allValue,
  });

  @override
  State<_PrayerAccordion> createState() => _PrayerAccordionState();
}

/// Sentinel for the "All prayers" row being open.
const _allRow = Object();

class _PrayerAccordionState extends State<_PrayerAccordion> {
  Object? _open;

  void _toggle(Object key) {
    HapticFeedback.selectionClick();
    setState(() => _open = _open == key ? null : key);
  }

  void _close() => setState(() => _open = null);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(height: 1, color: AppColors.borderWarm),
        if (widget.allEditor != null) ...[
          _row(
            key: _allRow,
            leading: Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amber.withValues(alpha: 0.18),
                border: Border.all(color: AppColors.amber),
              ),
              child: Icon(
                Icons.done_all_rounded,
                size: 18.sp,
                color: AppColors.amberDeep,
              ),
            ),
            title: 'All prayers',
            subtitle: 'Same duration for every prayer',
            trailingTop: widget.allValue != null
                ? formatDndMinutes(widget.allValue!)
                : '${widget.settings.configuredCount} of 5 set',
            editor: widget.allEditor!(_close),
            highlighted: widget.allValue != null,
          ),
          Divider(height: 1, color: AppColors.borderWarm),
        ],
        for (final prayer in PrayerName.values) ...[
          _prayerRow(prayer),
          Divider(height: 1, color: AppColors.borderWarm),
        ],
      ],
    );
  }

  Widget _prayerRow(PrayerName prayer) {
    final minutes = widget.settings.minutesFor(prayer);
    final time = widget.times[prayer];
    return _row(
      key: prayer,
      leading: _PrayerBadge(prayer: prayer, configured: minutes != null),
      title: prayerLabels[prayer]!,
      subtitle: time == null ? 'Time unavailable' : _time(time),
      trailingTop: minutes == null ? null : formatDndMinutes(minutes),
      trailingBottom: minutes != null && time != null
          ? 'until ${_time(time.add(Duration(minutes: minutes)))}'
          : null,
      onRemove: minutes == null
          ? null
          : () {
              if (_open == prayer) _close();
              widget.onClear(prayer);
            },
      removeFor: prayer,
      editor: widget.editorFor(prayer, _close),
      highlighted: minutes != null,
    );
  }

  Widget _row({
    required Object key,
    required Widget leading,
    required String title,
    required String subtitle,
    String? trailingTop,
    String? trailingBottom,
    VoidCallback? onRemove,
    PrayerName? removeFor,
    required Widget editor,
    required bool highlighted,
  }) {
    final open = _open == key;
    return Column(
      children: [
        PressScale(
          child: InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () => _toggle(key),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Row(
                children: [
                  leading,
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkText,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailingTop != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedText(
                          trailingTop,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                            color: highlighted
                                ? AppColors.amberDeep
                                : AppColors.textMuted,
                          ),
                        ),
                        if (trailingBottom != null)
                          Text(
                            trailingBottom,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      'Not set',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (onRemove != null && removeFor != null) ...[
                    SizedBox(width: 4.w),
                    _RemoveButton(prayer: removeFor, onTap: onRemove),
                  ],
                  SizedBox(width: 2.w),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: context.motion.duration(AppMotion.fast),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ExpandSection(expanded: open, child: editor),
      ],
    );
  }
}

// ── Fixed: preset pills inside the accordion ────────────────────────────

class _FixedBody extends StatelessWidget {
  final DndSettings settings;
  final Map<PrayerName, DateTime> times;
  final Future<void> Function(PrayerName, int) onSet;
  final Future<void> Function(PrayerName) onClear;
  final Future<void> Function(int) onSetAll;
  final Future<void> Function() onClearAll;

  const _FixedBody({
    required this.settings,
    required this.times,
    required this.onSet,
    required this.onClear,
    required this.onSetAll,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final values = settings.durations.values.toSet();
    final allValue =
        settings.configuredCount == PrayerName.values.length &&
            values.length == 1
        ? values.first
        : null;

    return _PrayerAccordion(
      settings: settings,
      times: times,
      onClear: onClear,
      allValue: allValue,
      allEditor: (close) => _PillsEditor(
        selected: allValue,
        onPick: (m) {
          close();
          allValue == m ? onClearAll() : onSetAll(m);
        },
      ),
      editorFor: (prayer, close) {
        final current = settings.minutesFor(prayer);
        return _PillsEditor(
          selected: current,
          onPick: (m) {
            close();
            current == m ? onClear(prayer) : onSet(prayer, m);
          },
        );
      },
    );
  }
}

class _PillsEditor extends StatelessWidget {
  final int? selected;
  final ValueChanged<int> onPick;
  const _PillsEditor({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final m in DndSettings.presetMinutes)
              _Pill(
                label: m == 60 ? '1 hour' : '$m min',
                selected: selected == m,
                onTap: () => onPick(m),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Custom: slider inside the accordion ─────────────────────────────────

class _CustomBody extends StatelessWidget {
  final DndSettings settings;
  final Map<PrayerName, DateTime> times;
  final Future<void> Function(PrayerName, int) onSet;
  final Future<void> Function(int) onSetAll;
  final Future<void> Function(PrayerName) onClear;

  const _CustomBody({
    required this.settings,
    required this.times,
    required this.onSet,
    required this.onSetAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _PrayerAccordion(
      settings: settings,
      times: times,
      onClear: onClear,
      editorFor: (prayer, close) {
        final minutes = settings.minutesFor(prayer);
        return _CustomEditor(
          key: ValueKey(prayer),
          time: times[prayer],
          initial: minutes ?? DndSettings.defaultCustomMinutes,
          configured: minutes != null,
          onSave: (m) async {
            close();
            await onSet(prayer, m);
          },
          onSaveAll: (m) async {
            close();
            await onSetAll(m);
          },
        );
      },
    );
  }
}

class _CustomEditor extends StatefulWidget {
  final DateTime? time;
  final int initial;
  final bool configured;
  final Future<void> Function(int) onSave;
  final Future<void> Function(int) onSaveAll;

  const _CustomEditor({
    super.key,
    required this.time,
    required this.initial,
    required this.configured,
    required this.onSave,
    required this.onSaveAll,
  });

  @override
  State<_CustomEditor> createState() => _CustomEditorState();
}

class _CustomEditorState extends State<_CustomEditor> {
  late double _value = widget.initial.toDouble();

  int get _minutes => _value.round();

  Widget _stat(String label, String value, {bool accent = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.amber.withValues(alpha: 0.16)
              : AppColors.parchment,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: accent ? AppColors.amber : AppColors.borderWarm,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10.5.sp, color: AppColors.textMuted),
            ),
            SizedBox(height: 3.h),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: accent ? AppColors.amberDeep : AppColors.inkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.time;
    final end = start?.add(Duration(minutes: _minutes));

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        children: [
          Row(
            children: [
              _stat('Start time', start == null ? '—' : _time(start)),
              SizedBox(width: 8.w),
              _stat('DND duration', formatDndMinutes(_minutes), accent: true),
              SizedBox(width: 8.w),
              _stat('End time', end == null ? '—' : _time(end)),
            ],
          ),
          SizedBox(height: 6.h),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: AppColors.amber,
              inactiveTrackColor: AppColors.borderWarm,
              thumbColor: AppColors.amber,
              overlayColor: AppColors.amber.withValues(alpha: 0.18),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 11,
                elevation: 2,
              ),
              valueIndicatorColor: AppColors.amberDeep,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Slider(
              value: _value,
              min: DndSettings.minCustomMinutes.toDouble(),
              max: DndSettings.maxCustomMinutes.toDouble(),
              divisions:
                  DndSettings.maxCustomMinutes - DndSettings.minCustomMinutes,
              label: formatDndMinutes(_minutes),
              semanticFormatterCallback: (v) => formatDndMinutes(v.round()),
              onChanged: (v) {
                final before = _minutes;
                setState(() => _value = v);
                if (_minutes != before && _minutes % 15 == 0) {
                  HapticFeedback.selectionClick();
                }
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final t in const [
                  '1 min',
                  '30 min',
                  '1 h',
                  '1.5 h',
                  '2 h',
                ])
                  Text(
                    t,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onSaveAll(_minutes);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amberDeep,
                    side: BorderSide(color: AppColors.amber),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'Apply to all',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onSave(_minutes);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: _onSelected,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    widget.configured ? 'Update' : 'Save',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
