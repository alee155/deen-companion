import 'package:deen_companion/features/groups/data/models/group_model.dart';
import 'package:deen_companion/features/groups/domain/entities/group.dart';
import 'package:deen_companion/features/groups/domain/entities/group_detail.dart';
import 'package:deen_companion/features/groups/presentation/widgets/snap_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://res.cloudinary.com/x/avatars/a?_a=B';

void main() {
  test('group detail parses group and member avatarUrl', () {
    final d = GroupDetailModel.fromJson({
      'id': 'g',
      'name': 'G',
      'avatarUrl': _url,
      'members': [
        {'userId': 'u', 'name': 'Ali', 'role': 'admin', 'avatarUrl': _url},
      ],
    }).toEntity();
    expect(d.avatarUrl, _url);
    expect(d.members.single.avatarUrl, _url);
  });

  testWidgets('MemberAvatar loads the picture when there is one', (t) async {
    await t.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MemberAvatar(
                  member: GroupMember(
                    userId: 'u',
                    name: 'Ali',
                    email: '',
                    role: GroupRole.admin,
                    avatarUrl: _url,
                  ),
                  size: 44,
                ),
                MemberAvatar(
                  member: GroupMember(
                    userId: 'v',
                    name: 'Bo',
                    email: '',
                    role: GroupRole.member,
                  ),
                  size: 44,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
