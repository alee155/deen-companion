import 'package:deen_companion/features/hadith/domain/hadith_cover_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/hadith_collection.dart';

class HadithBookCard extends StatelessWidget {
  final HadithCollection collection;
  final VoidCallback onTap;

  const HadithBookCard({
    super.key,
    required this.collection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: collection.key,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: const Color(0xffD8C08A).withOpacity(.45),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        HadithCoverAssets.forKey(collection.key),
                        fit: BoxFit.cover,
                      ),

                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Color(0xFFD9A441).withOpacity(.25),
                              Color(0xFFD9A441).withOpacity(.25),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: 10.w,
                        right: 10.w,
                        bottom: 10.h,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),

                            SizedBox(height: 8.h),

                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.18),
                                borderRadius: BorderRadius.circular(30.r),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '${collection.totalHadiths} Hadiths',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
