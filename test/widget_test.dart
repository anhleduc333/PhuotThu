import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/app/app.dart';

void main() {
  testWidgets('PhuotThu app starts successfully', (tester) async {
    await tester.pumpWidget(const PhuotThuApp());

    expect(find.text('PhuotThu'), findsOneWidget);
    expect(find.text('Sẵn sàng cho hành trình đầu tiên'), findsOneWidget);
  });
}
