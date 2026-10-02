import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/app/app.dart';

void main() {
  testWidgets('PhuotThu app starts successfully', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PhuotThuApp()));

    await tester.pumpAndSettle();

    expect(find.text('PhuotThu'), findsOneWidget);
    expect(find.text('Sẵn sàng cho hành trình đầu tiên'), findsOneWidget);
  });
}
