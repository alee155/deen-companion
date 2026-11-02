import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/widgets/feature_hero.dart';

/// The banner at the top of the sign-in screens, with an optional back button
/// over it. It is the same dark hero the rest of the app opens with; the
/// screen's own title sits in the card below, so only the backdrop and a
/// large [ghostIcon] show here.
class AuthTopHeader extends StatelessWidget {
  final IconData ghostIcon;
  final VoidCallback? onBack;

  const AuthTopHeader({super.key, required this.ghostIcon, this.onBack});

  @override
  Widget build(BuildContext context) {
    return HeroSurface(
      ghostIcon: ghostIcon,
      child: onBack == null
          ? null
          : Positioned(
              top: 10.h,
              left: 10.w,
              child: SafeArea(
                bottom: false,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
    );
  }
}
