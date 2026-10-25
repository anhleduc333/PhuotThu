import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/data/trip_live_location_publisher.dart';
import 'package:phuotthu/features/group_travel/data/trip_live_location_repository.dart';
import 'package:phuotthu/features/group_travel/data/trip_location_source.dart';
import 'package:phuotthu/features/group_travel/domain/trip_device_location.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_location.dart';

void main() {
  TripDeviceLocation location({
    double latitude = 21.0,
    double longitude = 105.0,
    int seconds = 0,
  }) {
    return TripDeviceLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: 5,
      speedMetersPerSecond: 10,
      headingDegrees: 90,
      measuredAt: DateTime.utc(2026, 10, 25, 3, 0, seconds),
    );
  }

  group('TripLiveLocationPublishPolicy', () {
    const policy = TripLiveLocationPublishPolicy();

    test('first location is always published', () {
      expect(
        policy.shouldPublish(candidate: location(), lastPublished: null),
        isTrue,
      );
    });

    test('rejects out-of-order location', () {
      expect(
        policy.shouldPublish(
          candidate: location(seconds: 7),
          lastPublished: location(seconds: 8),
        ),
        isFalse,
      );
    });

    test('rejects location before minimum interval', () {
      expect(
        policy.shouldPublish(
          candidate: location(latitude: 21.001, seconds: 5),
          lastPublished: location(),
        ),
        isFalse,
      );
    });

    test('publishes meaningful movement after minimum interval', () {
      expect(
        policy.shouldPublish(
          candidate: location(latitude: 21.0002, seconds: 8),
          lastPublished: location(),
        ),
        isTrue,
      );
    });

    test('small movement waits for heartbeat', () {
      expect(
        policy.shouldPublish(
          candidate: location(latitude: 21.00001, seconds: 8),
          lastPublished: location(),
        ),
        isFalse,
      );
    });

    test('heartbeat publishes stationary location', () {
      expect(
        policy.shouldPublish(
          candidate: location(seconds: 30),
          lastPublished: location(),
        ),
        isTrue,
      );
    });

    test('distance calculation is approximately correct', () {
      final meters = TripLiveLocationPublishPolicy.distanceMeters(
        21,
        105,
        21.001,
        105,
      );

      expect(meters, inInclusiveRange(110, 112));
    });
  });

  group('TripLiveLocationPublisher', () {
    test('reports service disabled without opening stream', () async {
      final source = _FakeLocationSource(
        accessStatus: TripLocationAccessStatus.serviceDisabled,
      );

      final repository = _FakeLiveLocationRepository();

      final publisher = TripLiveLocationPublisher(
        locationSource: source,
        repository: repository,
      );

      final result = await publisher.start('trip-1');

      expect(result.canReadLocation, isFalse);
      expect(
        publisher.status.state,
        TripLiveLocationPublisherState.serviceDisabled,
      );
      expect(source.watchCount, 0);

      await publisher.dispose();
      await source.dispose();
    });

    test('publishes first GPS location', () async {
      final source = _FakeLocationSource();
      final repository = _FakeLiveLocationRepository();

      final publisher = TripLiveLocationPublisher(
        locationSource: source,
        repository: repository,
      );

      await publisher.start('trip-1');

      source.add(location());

      await publisher.flush();

      expect(repository.published.length, 1);
      expect(repository.published.single.tripId, 'trip-1');
      expect(publisher.status.publishCount, 1);

      await publisher.dispose();
      await source.dispose();
    });

    test('throttles insignificant GPS update', () async {
      final source = _FakeLocationSource();
      final repository = _FakeLiveLocationRepository();

      final publisher = TripLiveLocationPublisher(
        locationSource: source,
        repository: repository,
      );

      await publisher.start('trip-1');

      source.add(location());
      source.add(location(latitude: 21.00001, seconds: 8));

      await publisher.flush();

      expect(repository.published.length, 1);

      await publisher.dispose();
      await source.dispose();
    });

    test('publishes moved location after interval', () async {
      final source = _FakeLocationSource();
      final repository = _FakeLiveLocationRepository();

      final publisher = TripLiveLocationPublisher(
        locationSource: source,
        repository: repository,
      );

      await publisher.start('trip-1');

      source.add(location());
      source.add(location(latitude: 21.0002, seconds: 8));

      await publisher.flush();

      expect(repository.published.length, 2);

      await publisher.dispose();
      await source.dispose();
    });

    test('publishes heartbeat even without movement', () async {
      final source = _FakeLocationSource();
      final repository = _FakeLiveLocationRepository();

      final publisher = TripLiveLocationPublisher(
        locationSource: source,
        repository: repository,
      );

      await publisher.start('trip-1');

      source.add(location());
      source.add(location(seconds: 30));

      await publisher.flush();

      expect(repository.published.length, 2);

      await publisher.dispose();
      await source.dispose();
    });

    test('stop can clear remote live location', () async {
      final source = _FakeLocationSource();
      final repository = _FakeLiveLocationRepository();

      final publisher = TripLiveLocationPublisher(
        locationSource: source,
        repository: repository,
      );

      await publisher.start('trip-1');

      await publisher.stop(clearRemote: true);

      expect(repository.clearedTrips, ['trip-1']);

      await publisher.dispose();
      await source.dispose();
    });

    test('invalid trip id is rejected', () async {
      final publisher = TripLiveLocationPublisher(
        locationSource: _FakeLocationSource(),
        repository: _FakeLiveLocationRepository(),
      );

      await expectLater(publisher.start('   '), throwsArgumentError);

      await publisher.dispose();
    });
  });
}

class _FakeLocationSource implements TripLocationSource {
  _FakeLocationSource({this.accessStatus = TripLocationAccessStatus.ready});

  final TripLocationAccessStatus accessStatus;

  final StreamController<TripDeviceLocation> _controller =
      StreamController<TripDeviceLocation>.broadcast(sync: true);

  int watchCount = 0;

  @override
  Future<TripLocationAccessResult> ensureAccess() async {
    return TripLocationAccessResult(status: accessStatus);
  }

  @override
  Stream<TripDeviceLocation> watchLocations() {
    watchCount += 1;
    return _controller.stream;
  }

  void add(TripDeviceLocation location) {
    _controller.add(location);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class _FakeLiveLocationRepository implements TripLiveLocationRepository {
  final List<TripLiveLocationUpdate> published = [];

  final List<String> clearedTrips = [];

  @override
  Future<void> clearMyLocation(String tripId) async {
    clearedTrips.add(tripId);
  }

  @override
  Future<void> publishMyLocation(TripLiveLocationUpdate update) async {
    published.add(update);
  }

  @override
  Stream<List<TripLiveLocation>> watchTripLocations(String tripId) {
    return const Stream<List<TripLiveLocation>>.empty();
  }
}
