import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A group's picture: bundled asset, a picked local file, or an icon.
class GroupImage extends StatelessWidget {
  final String? path;
  final double size;
  final double radius;

  const GroupImage({
    super.key,
    required this.path,
    required this.size,
    required this.radius,
  });

  Widget _fallback() => Container(
    color: AppColors.worshipAccentBg,
    alignment: Alignment.center,
    child: Icon(
      Icons.groups_rounded,
      color: AppColors.worshipAccent,
      size: size * 0.42,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = path;
    Widget child;
    if (p == null) {
      child = _fallback();
    } else if (p.startsWith('assets/')) {
      child = Image.asset(
        p,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else {
      child = Image.file(
        File(p),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
