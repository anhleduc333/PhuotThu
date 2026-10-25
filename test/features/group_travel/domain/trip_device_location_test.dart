import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_device_location.dart';

void main() {
  test('valid device location is accepted', () {
    final location = TripDeviceLocation(
      latitude: 21.0285,
      longitude: 105.8542,
      accuracyMeters: 8,
      speedMetersPerSecond: 5,
      headingDegrees: 90,
      measuredAt: DateTime.utc(2026, 10, 25),
    );

    expect(location.isValid, isTrue);
  });

  test('invalid latitude is rejected', () {
    final location = TripDeviceLocation(
      latitude: 91,
      longitude: 105,
      measuredAt: DateTime.utc(2026, 10, 25),
    );

    expect(location.isValid, isFalse);
  });

  test('invalid longitude is rejected', () {
    final location = TripDeviceLocation(
      latitude: 21,
      longitude: 181,
      measuredAt: DateTime.utc(2026, 10, 25),
    );

    expect(location.isValid, isFalse);
  });

  test('negative optional measurements are rejected', () {
    final location = TripDeviceLocation(
      latitude: 21,
      longitude: 105,
      accuracyMeters: -1,
      measuredAt: DateTime.utc(2026, 10, 25),
    );

    expect(location.isValid, isFalse);
  });

  test('normalized converts timestamp to UTC', () {
    final location = TripDeviceLocation(
      latitude: 21,
      longitude: 105,
      measuredAt: DateTime.parse('2026-10-25T10:00:00+07:00'),
    );

    final normalized = location.normalized();

    expect(normalized.measuredAt.isUtc, isTrue);
    expect(normalized.measuredAt.hour, 3);
  });
}
