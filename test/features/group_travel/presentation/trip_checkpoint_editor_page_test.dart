import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/presentation/trip_checkpoint_editor_page.dart';

void main() {
  test('form values map into existing DEV-09.7B create/update inputs', () {
    final data = TripCheckpointFormData(
      name: 'Cổng trời',
      note: null,
      latitude: 23.05,
      longitude: 105.01,
      radiusM: 150,
      sortOrder: 2,
      isRequired: true,
      autoArrivalEnabled: false,
    );

    final create = data.toCreateInput('trip-id').toInsertJson();
    expect(create['trip_id'], 'trip-id');
    expect(create['name'], 'Cổng trời');
    expect(create['radius_m'], 150);
    expect(create['auto_arrival_enabled'], false);

    final update = data.toUpdateInput().toUpdateJson();
    expect(update['name'], 'Cổng trời');
    expect(update['note'], isNull);
    expect(update['planned_at'], isNull);
  });

  testWidgets('checkpoint editor requires name and coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TripCheckpointEditorPage()),
    );

    // The editor has a scrollable form and its save button is below the
    // initial viewport. Search by its label (FilledButton.icon has a private
    // implementation type, so widgetWithText(FilledButton, ...) is fragile).
    final save = find.text('Tạo điểm hẹn');
    expect(save, findsOneWidget);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Validation must include fields above the visible viewport as well.
    expect(find.text('Vui lòng nhập tên điểm hẹn.'), findsOneWidget);
    expect(find.text('Nhập tọa độ hợp lệ.'), findsNWidgets(2));
  });
}
