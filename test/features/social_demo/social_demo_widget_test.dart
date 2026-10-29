import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/community/presentation/pages/community_page.dart';
import 'package:phuotthu/features/community/presentation/pages/demo_call_page.dart';
import 'package:phuotthu/features/home/presentation/pages/home_page.dart';

void main() {
  testWidgets('Trang chủ hiển thị bảng tin và mở tạo bài', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('PhuotThu'), findsOneWidget);
    expect(find.textContaining('Bảng tin cộng đồng'), findsOneWidget);
    expect(find.text('Khám phá hành trình'), findsOneWidget);

    await tester.tap(find.byTooltip('Tạo bài viết'));
    await tester.pumpAndSettle();
    expect(find.text('Chia sẻ hành trình'), findsOneWidget);
    expect(find.byKey(const Key('demo-compose-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('demo-compose-field')),
      'Mình vừa đi cung Tam Đảo!',
    );
    await tester.pump();
    expect(find.text('Đăng bài'), findsWidgets);
  });

  testWidgets('Cộng đồng mở hội thoại và gửi tin nhắn', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityPage()));
    expect(find.text('Cộng đồng'), findsOneWidget);
    expect(find.text('Đội phượt cuối tuần'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-riders')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Trò chuyện nhanh với bạn đồng hành'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('demo-chat-input')),
      'Đã kiểm tra lộ trình!',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('demo-chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Đã kiểm tra lộ trình!'), findsOneWidget);
  });

  testWidgets('Mở và kết thúc màn hình gọi thoại', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityPage()));
    await tester.tap(find.byKey(const Key('chat-riders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gọi thoại'));
    await tester.pumpAndSettle();
    expect(find.text('Cuộc gọi thoại'), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-call-end')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-chat-input')), findsOneWidget);
  });

  testWidgets('Màn hình gọi không tràn ở kích thước nhỏ', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoCallPage(
          name: 'Nhóm phượt thử nghiệm',
          initials: 'PT',
          avatarColor: Colors.teal,
          isVideo: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('demo-call-end')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
