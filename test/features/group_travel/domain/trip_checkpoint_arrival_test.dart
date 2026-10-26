import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_checkpoint_arrival.dart';

void main() {
  Map<String, dynamic> sample() => {
    'checkpoint_id': 'cp-1',
    'user_id': 'user-1',
    'arrived_at': '2026-10-26T12:00:00+07:00',
    'arrival_method': 'manual',
    'distance_m': null,
    'gps_accuracy_m': null,
  };

  test('manual arrival parses and round trips', () {
    final arrival = TripCheckpointArrival.fromJson(sample());
    expect(arrival.method, TripCheckpointArrivalMethod.manual);
    expect(arrival.arrivedAt.isUtc, isTrue);
    expect(arrival.arrivedAt.hour, 5);
    expect(arrival.distanceM, isNull);
    expect(TripCheckpointArrival.fromJson(arrival.toJson()).userId, 'user-1');
  });

  test('GPS arrival can be parsed but is not inserted by the client', () {
    final arrival = TripCheckpointArrival.fromJson({
      ...sample(),
      'arrival_method': 'gps',
      'distance_m': 25,
      'gps_accuracy_m': 8.5,
    });
    expect(arrival.method, TripCheckpointArrivalMethod.gps);
    expect(arrival.gpsAccuracyM, 8.5);
  });

  test('rejects invalid method, distance and timestamp', () {
    expect(
      () => TripCheckpointArrival.fromJson({
        ...sample(),
        'arrival_method': 'admin',
      }),
      throwsFormatException,
    );
    expect(
      () => TripCheckpointArrival.fromJson({...sample(), 'distance_m': -2}),
      throwsFormatException,
    );
    expect(
      () => TripCheckpointArrival.fromJson({
        ...sample(),
        'arrived_at': 'not-date',
      }),
      throwsFormatException,
    );
  });
}
