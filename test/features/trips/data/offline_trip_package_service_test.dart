import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/data/offline_trip_cache_repository.dart';
import 'package:phuotthu/features/trips/data/offline_trip_package_service.dart';
import 'package:phuotthu/features/trips/domain/offline_trip_package_snapshot.dart';

void main() {
  test('builds, saves and loads package', () async {
    final repository = _MemoryRepository();
    final service = OfflineTripPackageService(repository: repository);

    final saved = await service.savePackage(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: const [
        RoutePoint(latitude: 21, longitude: 105),
        RoutePoint(latitude: 22, longitude: 106),
      ],
      savedAt: DateTime.utc(2026, 10, 25),
    );

    expect(saved.trip.tripId, 'trip-1');
    expect(await service.hasPackage('trip-1'), isTrue);

    final loaded = await service.loadPackage('trip-1');

    expect(loaded, isNotNull);
    expect(loaded!.route.distanceMeters, 100000);
  });

  test('removePackage delegates to repository', () async {
    final repository = _MemoryRepository();
    final service = OfflineTripPackageService(repository: repository);

    await service.savePackage(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: const [
        RoutePoint(latitude: 21, longitude: 105),
        RoutePoint(latitude: 22, longitude: 106),
      ],
    );

    await service.removePackage('trip-1');

    expect(await service.hasPackage('trip-1'), isFalse);
    expect(await service.loadPackage('trip-1'), isNull);
  });

  test('does not save when builder validation fails', () async {
    final repository = _MemoryRepository();
    final service = OfflineTripPackageService(repository: repository);

    expect(
      () => service.savePackage(
        tripId: '',
        startName: 'A',
        destinationName: 'B',
        startLatitude: 21,
        startLongitude: 105,
        destinationLatitude: 22,
        destinationLongitude: 106,
        routeDistanceMeters: 100000,
        routeDurationSeconds: 7200,
        routePoints: const [
          RoutePoint(latitude: 21, longitude: 105),
          RoutePoint(latitude: 22, longitude: 106),
        ],
      ),
      throwsArgumentError,
    );

    expect(repository.saved, isEmpty);
  });

  test('propagates repository save failure', () async {
    final service = OfflineTripPackageService(repository: _FailingRepository());

    expect(
      () => service.savePackage(
        tripId: 'trip-1',
        startName: 'A',
        destinationName: 'B',
        startLatitude: 21,
        startLongitude: 105,
        destinationLatitude: 22,
        destinationLongitude: 106,
        routeDistanceMeters: 100000,
        routeDurationSeconds: 7200,
        routePoints: const [
          RoutePoint(latitude: 21, longitude: 105),
          RoutePoint(latitude: 22, longitude: 106),
        ],
      ),
      throwsStateError,
    );
  });
}

class _MemoryRepository implements OfflineTripCacheRepository {
  final Map<String, OfflineTripPackageSnapshot> saved = {};

  @override
  Future<List<String>> cachedTripIds() async {
    final ids = saved.keys.toList(growable: false)..sort();
    return ids;
  }

  @override
  Future<void> clearAll() async {
    saved.clear();
  }

  @override
  Future<bool> exists(String tripId) async {
    return saved.containsKey(tripId);
  }

  @override
  Future<OfflineTripPackageSnapshot?> load(String tripId) async {
    return saved[tripId];
  }

  @override
  Future<void> remove(String tripId) async {
    saved.remove(tripId);
  }

  @override
  Future<void> save(OfflineTripPackageSnapshot snapshot) async {
    saved[snapshot.trip.tripId] = snapshot;
  }
}

class _FailingRepository implements OfflineTripCacheRepository {
  @override
  Future<List<String>> cachedTripIds() async => const [];

  @override
  Future<void> clearAll() async {}

  @override
  Future<bool> exists(String tripId) async => false;

  @override
  Future<OfflineTripPackageSnapshot?> load(String tripId) async => null;

  @override
  Future<void> remove(String tripId) async {}

  @override
  Future<void> save(OfflineTripPackageSnapshot snapshot) async {
    throw StateError('disk full');
  }
}
