import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/app/app.dart';

void main() {
  testWidgets('PhuotThu main navigation is displayed', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PhuotThuApp()));

    await tester.pumpAndSettle();

    expect(find.text('Trang chủ PhuotThu'), findsOneWidget);

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Chuyến đi'), findsOneWidget);
    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Cộng đồng'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
  });
}
