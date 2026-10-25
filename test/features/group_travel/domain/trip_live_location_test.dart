import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_location.dart';

void main() {
  Map<String, dynamic> json({
    double latitude = 21.0285,
    double longitude = 105.8542,
    double? accuracy = 8.5,
    double? speed = 12.0,
    double? heading = 90.0,
    String recordedAt = '2026-10-25T03:00:00Z',
  }) {
    return {
      'id': 'location-1',
      'trip_id': 'trip-1',
      'user_id': 'user-1',
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracy,
      'speed_mps': speed,
      'heading_deg': heading,
      'recorded_at': recordedAt,
      'updated_at': '2026-10-25T03:00:05Z',
    };
  }

  test('parses live location payload', () {
    final location = TripLiveLocation.fromJson(json());

    expect(location.id, 'location-1');
    expect(location.tripId, 'trip-1');
    expect(location.userId, 'user-1');
    expect(location.latitude, 21.0285);
    expect(location.longitude, 105.8542);
    expect(location.accuracyMeters, 8.5);
    expect(location.speedMetersPerSecond, 12.0);
    expect(location.headingDegrees, 90.0);
  });

  test('normalizes timestamps to UTC', () {
    final location = TripLiveLocation.fromJson(
      json(recordedAt: '2026-10-25T10:00:00+07:00'),
    );

    expect(location.recordedAt.isUtc, isTrue);
    expect(location.recordedAt.hour, 3);
    expect(location.updatedAt.isUtc, isTrue);
  });

  test('location inside freshness window is fresh', () {
    final location = TripLiveLocation.fromJson(json());

    expect(location.isFreshAt(DateTime.utc(2026, 10, 25, 3, 1)), isTrue);
  });

  test('location outside freshness window is stale', () {
    final location = TripLiveLocation.fromJson(json());

    expect(location.isStaleAt(DateTime.utc(2026, 10, 25, 3, 3)), isTrue);
  });

  test('future recordedAt is treated as zero age', () {
    final location = TripLiveLocation.fromJson(json());

    expect(location.ageAt(DateTime.utc(2026, 10, 25, 2, 59)), Duration.zero);
  });

  test('rejects invalid latitude', () {
    expect(
      () => TripLiveLocation.fromJson(json(latitude: 91)),
      throwsFormatException,
    );
  });

  test('rejects invalid longitude', () {
    expect(
      () => TripLiveLocation.fromJson(json(longitude: 181)),
      throwsFormatException,
    );
  });

  test('rejects negative accuracy', () {
    expect(
      () => TripLiveLocation.fromJson(json(accuracy: -1)),
      throwsFormatException,
    );
  });

  test('rejects invalid heading', () {
    expect(
      () => TripLiveLocation.fromJson(json(heading: 360)),
      throwsFormatException,
    );
  });

  test('update produces RPC parameters in UTC', () {
    final update = TripLiveLocationUpdate(
      tripId: ' trip-1 ',
      latitude: 21.0,
      longitude: 105.0,
      accuracyMeters: 5,
      speedMetersPerSecond: 10,
      headingDegrees: 180,
      recordedAt: DateTime.parse('2026-10-25T10:00:00+07:00'),
    );

    final params = update.toRpcParams();

    expect(params['p_trip_id'], 'trip-1');
    expect(params['p_recorded_at'], '2026-10-25T03:00:00.000Z');
  });

  test('invalid update cannot produce RPC parameters', () {
    final update = TripLiveLocationUpdate(
      tripId: 'trip-1',
      latitude: 95,
      longitude: 105,
      recordedAt: DateTime.utc(2026, 10, 25),
    );

    expect(update.isValid, isFalse);
    expect(update.toRpcParams, throwsStateError);
  });

  test('negative freshness window is rejected', () {
    final location = TripLiveLocation.fromJson(json());

    expect(
      () => location.isFreshAt(
        DateTime.utc(2026, 10, 25, 3, 1),
        freshnessWindow: const Duration(seconds: -1),
      ),
      throwsArgumentError,
    );
  });
}
