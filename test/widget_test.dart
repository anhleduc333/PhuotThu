import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/app/app.dart';
import 'package:phuotthu/app/router/app_router.dart';

void main() {
  testWidgets('Unauthenticated user is redirected to login', (tester) async {
    final router = createAppRouter(isAuthenticated: () => false);

    await tester.pumpWidget(ProviderScope(child: PhuotThuApp(router: router)));

    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsOneWidget);

    expect(find.text('Đăng nhập để bắt đầu hành trình'), findsOneWidget);
  });
}
