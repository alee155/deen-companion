import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';

Future<Set<String>?> showOriginFilterSheet(
  BuildContext context, {
  required List<String> allOrigins,
  required Set<String> initiallySelected,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    backgroundColor: AppColors.surfaceLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (context) => _OriginFilterContent(
      allOrigins: allOrigins,
      initiallySelected: initiallySelected,
    ),
  );
}

class _OriginFilterContent extends StatefulWidget {
  final List<String> allOrigins;
  final Set<String> initiallySelected;
  const _OriginFilterContent({
    required this.allOrigins,
    required this.initiallySelected,
  });

  @override
  State<_OriginFilterContent> createState() => _OriginFilterContentState();
}

class _OriginFilterContentState extends State<_OriginFilterContent> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(top: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.borderWarm,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Filter by origin',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.inkText,
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 360.h),
              child: ListView(
                shrinkWrap: true,
                children: widget.allOrigins.map((origin) {
                  return CheckboxListTile(
                    value: _selected.contains(origin),
                    activeColor: AppColors.gold,
                    title: Text(origin),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(origin);
                      } else {
                        _selected.remove(origin);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selected = {}),
                      child: const Text('Clear'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
