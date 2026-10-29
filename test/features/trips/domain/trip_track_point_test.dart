import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/trip_track_point.dart';

void main() {
  test('track point JSON roundtrip and UTC normalization', () {
    final original = TripTrackPoint(
      latitude: 21.0278,
      longitude: 105.8523,
      measuredAt: DateTime.parse('2026-10-29T12:00:00+07:00'),
    );
    final restored = TripTrackPoint.fromJson(original.toJson());
    expect(restored.isValid, isTrue);
    expect(restored.measuredAt.isUtc, isTrue);
    expect(restored.measuredAt.hour, 5);
    expect(restored.metersTo(original), closeTo(0, 0.001));
  });

  test('invalid coordinates are rejected', () {
    expect(
      () => TripTrackPoint.fromJson({
        'latitude': 120,
        'longitude': 105.0,
        'measured_at': '2026-10-29T05:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
