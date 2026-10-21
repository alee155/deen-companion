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

/// "10 min before · 20 min after" (or just the after part with no lead).
String _shape(int lead, int after) => lead > 0
    ? '${formatDndMinutes(lead)} before · ${formatDndMinutes(after)} after'
    : '${formatDndMinutes(after)} after';

String _range(DateTime prayer, int lead, int after) =>
    '${_time(prayer.subtract(Duration(minutes: lead)))} – '
    '${_time(prayer.add(Duration(minutes: after)))}';

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

    Future<void> set(PrayerName prayer, int lead, int after) async {
      await notifier.setWindow(prayer, lead, after);
      await onChanged();
    }

    Future<void> clear(PrayerName prayer) async {
      await notifier.clearDuration(prayer);
      await onChanged();
    }

    Future<void> setAll(int lead, int after) async {
      await notifier.setAllWindows(lead, after);
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
          subtitle: 'Pick a ready-made window for each prayer',
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
          subtitle: 'Choose when it starts and ends around the prayer',
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
  final String? allValue;

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
            subtitle: 'Same window for every prayer',
            trailingTop:
                widget.allValue ??
                '${widget.settings.configuredCount} of 5 set',
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
    final lead = widget.settings.leadFor(prayer);
    final time = widget.times[prayer];
    return _row(
      key: prayer,
      leading: _PrayerBadge(prayer: prayer, configured: minutes != null),
      title: prayerLabels[prayer]!,
      subtitle: time == null ? 'Time unavailable' : 'Prayer at ${_time(time)}',
      trailingTop: minutes == null
          ? null
          : time != null
          ? _range(time, lead, minutes)
          : formatDndMinutes(minutes),
      trailingBottom: minutes == null ? null : _shape(lead, minutes),
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
  final Future<void> Function(PrayerName, int, int) onSet;
  final Future<void> Function(PrayerName) onClear;
  final Future<void> Function(int, int) onSetAll;
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
    // Every prayer set to the same window → the "All prayers" row shows it.
    DndPreset? allPreset;
    String? allSummary;
    if (settings.configuredCount == PrayerName.values.length) {
      final shapes = {
        for (final p in PrayerName.values)
          (settings.leadFor(p), settings.minutesFor(p)!),
      };
      if (shapes.length == 1) {
        final (lead, after) = shapes.first;
        allSummary = _shape(lead, after);
        for (final preset in DndSettings.presets) {
          if (preset.matches(lead, after)) allPreset = preset;
        }
      }
    }

    return _PrayerAccordion(
      settings: settings,
      times: times,
      onClear: onClear,
      allValue: allSummary,
      allEditor: (close) => _PresetsEditor(
        selected: allPreset,
        onPick: (preset) {
          close();
          allPreset == preset
              ? onClearAll()
              : onSetAll(preset.leadMinutes, preset.afterMinutes);
        },
      ),
      editorFor: (prayer, close) {
        final lead = settings.leadFor(prayer);
        final after = settings.minutesFor(prayer);
        DndPreset? current;
        if (after != null) {
          for (final preset in DndSettings.presets) {
            if (preset.matches(lead, after)) current = preset;
          }
        }
        return _PresetsEditor(
          selected: current,
          prayerTime: times[prayer],
          onPick: (preset) {
            close();
            current == preset
                ? onClear(prayer)
                : onSet(prayer, preset.leadMinutes, preset.afterMinutes);
          },
        );
      },
    );
  }
}

class _PresetsEditor extends StatelessWidget {
  final DndPreset? selected;
  final DateTime? prayerTime;
  final ValueChanged<DndPreset> onPick;
  const _PresetsEditor({
    required this.selected,
    required this.onPick,
    this.prayerTime,
  });

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
            for (final preset in DndSettings.presets)
              _PresetChip(
                preset: preset,
                prayerTime: prayerTime,
                selected: selected == preset,
                onTap: () => onPick(preset),
              ),
          ],
        ),
      ),
    );
  }
}

/// A preset card: its name, the shape of the window and (when a prayer time
/// is known) the exact clock range it would give.
class _PresetChip extends StatelessWidget {
  final DndPreset preset;
  final DateTime? prayerTime;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({
    required this.preset,
    required this.prayerTime,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? _onSelected : AppColors.textSecondary;
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: AppMotion.pressScaleSmall,
      child: AnimatedContainer(
        duration: context.motion.duration(AppMotion.fast),
        curve: AppMotion.entrance,
        constraints: BoxConstraints(minWidth: 132.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : AppColors.parchment,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: selected ? AppColors.amberDeep : AppColors.borderWarm,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w800,
                color: selected ? _onSelected : AppColors.inkText,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              _shape(preset.leadMinutes, preset.afterMinutes),
              style: TextStyle(fontSize: 11.sp, color: fg),
            ),
            if (prayerTime != null)
              Text(
                _range(prayerTime!, preset.leadMinutes, preset.afterMinutes),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
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
  final Future<void> Function(PrayerName, int, int) onSet;
  final Future<void> Function(int, int) onSetAll;
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
          initialLead: minutes == null
              ? DndSettings.defaultLeadMinutes
              : settings.leadFor(prayer),
          initialAfter: minutes ?? DndSettings.defaultCustomMinutes,
          configured: minutes != null,
          onSave: (lead, after) async {
            close();
            await onSet(prayer, lead, after);
          },
          onSaveAll: (lead, after) async {
            close();
            await onSetAll(lead, after);
          },
        );
      },
    );
  }
}

class _CustomEditor extends StatefulWidget {
  final DateTime? time;
  final int initialLead;
  final int initialAfter;
  final bool configured;
  final Future<void> Function(int lead, int after) onSave;
  final Future<void> Function(int lead, int after) onSaveAll;

  const _CustomEditor({
    super.key,
    required this.time,
    required this.initialLead,
    required this.initialAfter,
    required this.configured,
    required this.onSave,
    required this.onSaveAll,
  });

  @override
  State<_CustomEditor> createState() => _CustomEditorState();
}

class _CustomEditorState extends State<_CustomEditor> {
  /// Track runs from -maxLead (left) to +maxAfter (right); the prayer sits
  /// at 0 and is the fixed reference the two handles move around.
  static const _min = -DndSettings.maxLeadMinutes;
  static const _max = DndSettings.maxCustomMinutes;
  static const _overlay = 14.0;

  late RangeValues _values = RangeValues(
    -widget.initialLead.toDouble(),
    widget.initialAfter.toDouble(),
  );

  int get _lead => (-_values.start).round();
  int get _after => _values.end.round();

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

  void _onChanged(RangeValues v) {
    // The prayer is the reference: the left handle can't pass it, and the
    // right handle must stay at least a minute after it.
    final next = RangeValues(
      v.start.clamp(_min.toDouble(), 0),
      v.end.clamp(1, _max.toDouble()),
    );
    if (next.start.round() != _values.start.round() &&
        next.start.round() % 5 == 0) {
      HapticFeedback.selectionClick();
    }
    if (next.end.round() != _values.end.round() && next.end.round() % 15 == 0) {
      HapticFeedback.selectionClick();
    }
    setState(() => _values = next);
  }

  @override
  Widget build(BuildContext context) {
    final prayer = widget.time;

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        children: [
          Row(
            children: [
              _stat(
                'DND starts',
                prayer == null
                    ? '$_lead min before'
                    : _time(prayer.subtract(Duration(minutes: _lead))),
              ),
              SizedBox(width: 8.w),
              _stat(
                'Prayer',
                prayer == null ? '—' : _time(prayer),
                accent: true,
              ),
              SizedBox(width: 8.w),
              _stat(
                'DND ends',
                prayer == null
                    ? '$_after min after'
                    : _time(prayer.add(Duration(minutes: _after))),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          LayoutBuilder(
            builder: (context, box) {
              final trackWidth = box.maxWidth - _overlay * 2;
              final prayerX = _overlay + trackWidth * (-_min / (_max - _min));
              return Stack(
                alignment: Alignment.center,
                children: [
                  // The prayer-time reference line behind the handles.
                  Positioned(
                    left: prayerX - 1.5,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: AppColors.amberDeep,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: AppColors.amber,
                      inactiveTrackColor: AppColors.borderWarm,
                      thumbColor: AppColors.amber,
                      overlayColor: AppColors.amber.withValues(alpha: 0.18),
                      activeTickMarkColor: Colors.transparent,
                      inactiveTickMarkColor: Colors.transparent,
                      rangeThumbShape: const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 11,
                        elevation: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: _overlay,
                      ),
                    ),
                    child: RangeSlider(
                      values: _values,
                      min: _min.toDouble(),
                      max: _max.toDouble(),
                      divisions: _max - _min,
                      semanticFormatterCallback: (v) => v < 0
                          ? '${formatDndMinutes((-v).round())} before the prayer'
                          : '${formatDndMinutes(v.round())} after the prayer',
                      onChanged: _onChanged,
                    ),
                  ),
                ],
              );
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final t in const ['30 min before', 'Prayer', '2 h after'])
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
          SizedBox(height: 4.h),
          Text(
            _shape(_lead, _after),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.amberDeep,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onSaveAll(_lead, _after);
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
                    widget.onSave(_lead, _after);
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
