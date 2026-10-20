import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// A prayer-log photo from its signed URL. A failed load (expired signature,
/// offline) shows a placeholder rather than an error.
class SnapPhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;

  /// Called once the photo is on screen, or once it failed to load (the
  /// placeholder is then what is shown). May be called more than once.
  final VoidCallback? onReady;
  const SnapPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.onReady,
  });

  void _ready() {
    final cb = onReady;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => cb());
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) _ready();
        return child;
      },
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: AppColors.borderWarm,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
      errorBuilder: (context, _, _) {
        _ready();
        return ColoredBox(
          color: AppColors.borderWarm,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.textMuted,
            size: 22.sp,
          ),
        );
      },
    );
  }
}

/// Full-screen, Snapchat-style photo viewer: the whole photo is shown as the
/// sender framed it (never cropped), a progress bar runs along the top for
/// [duration] — the sender's chosen view time, counted from when the photo is
/// on screen — and closes it when full, the sender sits in the header. Tap to close, hold to pause, swipe down to dismiss.
Future<void> showSnapPhoto(
  BuildContext context, {
  required String url,
  required String title,
  String? subtitle,
  Widget? avatar,
  Duration duration = const Duration(seconds: 6),
}) {
  HapticFeedback.selectionClick();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close snap',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(
          begin: 0.92,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      ),
    ),
    pageBuilder: (_, _, _) => _SnapPhotoViewer(
      url: url,
      title: title,
      subtitle: subtitle,
      avatar: avatar,
      duration: duration,
    ),
  );
}

class _SnapPhotoViewer extends StatefulWidget {
  final String url;
  final String title;
  final String? subtitle;
  final Widget? avatar;
  final Duration duration;
  const _SnapPhotoViewer({
    required this.url,
    required this.title,
    required this.subtitle,
    required this.avatar,
    required this.duration,
  });

  @override
  State<_SnapPhotoViewer> createState() => _SnapPhotoViewerState();
}

class _SnapPhotoViewerState extends State<_SnapPhotoViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  double _drag = 0;
  bool _started = false;

  /// The clock starts when the photo is showing, not while it downloads, so
  /// the viewer always gets the full time the sender chose.
  void _start() {
    if (_started || !mounted) return;
    _started = true;
    _progress.forward().whenComplete(_close);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final fade = (1 - (_drag / 300)).clamp(0.4, 1.0);
    return Material(
      color: Colors.black.withValues(alpha: fade),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        onLongPressStart: (_) => _progress.stop(),
        onLongPressEnd: (_) {
          if (_started) _progress.forward().whenComplete(_close);
        },
        onVerticalDragUpdate: (d) =>
            setState(() => _drag = (_drag + d.delta.dy).clamp(0, 600)),
        onVerticalDragEnd: (d) {
          if (_drag > 120 || (d.primaryVelocity ?? 0) > 700) {
            _close();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_drag > 0 ? 24.r : 0),
                child: SnapPhoto(
                  url: widget.url,
                  // Contain, like the sender's preview: cover would crop it.
                  fit: BoxFit.contain,
                  onReady: _start,
                ),
              ),
              const _Scrim(top: true),
              const _Scrim(top: false),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 8.h, 4.w, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (_, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(2.r),
                          child: LinearProgressIndicator(
                            value: _progress.value,
                            minHeight: 3.h,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          if (widget.avatar != null) ...[
                            widget.avatar!,
                            SizedBox(width: 10.w),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 6,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.subtitle != null)
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 11.sp,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: _close,
                            icon: const Icon(Icons.close_rounded),
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Darkens the photo's top or bottom edge so white text stays readable.
class _Scrim extends StatelessWidget {
  final bool top;
  const _Scrim({required this.top});

  @override
  Widget build(BuildContext context) => Positioned(
    top: top ? 0 : null,
    bottom: top ? null : 0,
    left: 0,
    right: 0,
    height: top ? 150.h : 90.h,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: top ? 0.55 : 0.35),
              Colors.transparent,
            ],
          ),
        ),
      ),
    ),
  );
}
