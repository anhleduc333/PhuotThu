import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/data/offline_trip_cache_repository.dart';
import 'package:phuotthu/features/trips/domain/offline_trip_package_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  OfflineTripPackageSnapshot snapshot(String tripId) {
    return OfflineTripPackageSnapshot(
      schemaVersion: OfflineTripPackageSnapshot.currentSchemaVersion,
      savedAt: DateTime.utc(2026, 10, 25),
      trip: OfflineTripSnapshot(
        tripId: tripId,
        startName: 'A',
        destinationName: 'B',
        startLatitude: 21,
        startLongitude: 105,
        destinationLatitude: 22,
        destinationLongitude: 106,
      ),
      route: const OfflineRouteSnapshot(
        distanceMeters: 100000,
        durationSeconds: 7200,
        points: [
          OfflineRoutePointSnapshot(latitude: 21, longitude: 105),
          OfflineRoutePointSnapshot(latitude: 22, longitude: 106),
        ],
      ),
      pois: const [],
    );
  }

  late SharedPreferences preferences;
  late SharedPreferencesOfflineTripCacheRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesOfflineTripCacheRepository(preferences);
  });

  test('saves and loads package', () async {
    await repository.save(snapshot('trip-1'));

    final loaded = await repository.load('trip-1');

    expect(loaded, isNotNull);
    expect(loaded!.trip.tripId, 'trip-1');
    expect(await repository.exists('trip-1'), isTrue);
  });

  test('save overwrites same trip package', () async {
    await repository.save(snapshot('trip-1'));

    final updated = OfflineTripPackageSnapshot(
      schemaVersion: 1,
      savedAt: DateTime.utc(2026, 10, 26),
      trip: snapshot('trip-1').trip,
      route: snapshot('trip-1').route,
      pois: const [
        OfflinePoiSnapshot(
          id: 'poi-1',
          name: 'POI',
          typeKey: 'fuel',
          latitude: 21,
          longitude: 105,
          source: 'test',
          sourceId: '1',
        ),
      ],
    );

    await repository.save(updated);

    final loaded = await repository.load('trip-1');

    expect(loaded!.pois.length, 1);
    expect(loaded.savedAt, DateTime.utc(2026, 10, 26));
  });

  test('maintains sorted unique cached trip index', () async {
    await repository.save(snapshot('trip-b'));
    await repository.save(snapshot('trip-a'));
    await repository.save(snapshot('trip-b'));

    expect(await repository.cachedTripIds(), ['trip-a', 'trip-b']);
  });

  test('removes package and index entry', () async {
    await repository.save(snapshot('trip-1'));
    await repository.save(snapshot('trip-2'));

    await repository.remove('trip-1');

    expect(await repository.exists('trip-1'), isFalse);
    expect(await repository.load('trip-1'), isNull);
    expect(await repository.cachedTripIds(), ['trip-2']);
  });

  test('clearAll removes all cached packages', () async {
    await repository.save(snapshot('trip-1'));
    await repository.save(snapshot('trip-2'));

    await repository.clearAll();

    expect(await repository.cachedTripIds(), isEmpty);
    expect(await repository.exists('trip-1'), isFalse);
    expect(await repository.exists('trip-2'), isFalse);
  });

  test('returns null for missing package', () async {
    expect(await repository.load('missing'), isNull);
  });

  test('rejects blank trip id', () async {
    expect(() => repository.exists('   '), throwsArgumentError);
  });

  test('throws when cached JSON is corrupted', () async {
    await preferences.setString('offline_trip_package_v1:trip-1', '{bad json');

    expect(() => repository.load('trip-1'), throwsA(anything));
  });
}
