import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/offline_trip_package_snapshot.dart';

void main() {
  OfflineTripPackageSnapshot buildSnapshot({
    int schemaVersion = OfflineTripPackageSnapshot.currentSchemaVersion,
  }) {
    return OfflineTripPackageSnapshot(
      schemaVersion: schemaVersion,
      savedAt: DateTime.utc(2026, 10, 25, 2),
      trip: OfflineTripSnapshot(
        tripId: 'trip-1',
        startName: 'Hà Nội',
        destinationName: 'Hà Giang',
        startLatitude: 21.0285,
        startLongitude: 105.8542,
        destinationLatitude: 22.8233,
        destinationLongitude: 104.9836,
        vehicleId: 'vehicle-1',
        startAt: DateTime.utc(2026, 11, 1),
        budgetTotal: 3000000,
      ),
      route: const OfflineRouteSnapshot(
        distanceMeters: 300000,
        durationSeconds: 21600,
        points: [
          OfflineRoutePointSnapshot(latitude: 21.0285, longitude: 105.8542),
          OfflineRoutePointSnapshot(latitude: 22.8233, longitude: 104.9836),
        ],
      ),
      pois: const [
        OfflinePoiSnapshot(
          id: 'poi-1',
          name: 'Cây xăng A',
          typeKey: 'fuel',
          latitude: 21.5,
          longitude: 105.5,
          source: 'geoapify',
          sourceId: 'source-1',
          address: 'Địa chỉ A',
          distanceFromRouteMeters: 250,
        ),
      ],
      connectivity: OfflineConnectivitySnapshot(
        overallRiskScore: 0.62,
        overallLevelKey: 'high',
        warningRoutePercent: 28.5,
        proxyOnly: true,
        generatedAt: DateTime.utc(2026, 10, 25, 1),
        segments: const [
          OfflineConnectivitySegmentSnapshot(
            startDistanceMeters: 100000,
            endDistanceMeters: 160000,
            levelKey: 'high',
            averageRiskScore: 0.62,
            maxRiskScore: 0.74,
          ),
        ],
      ),
    );
  }

  group('OfflineTripPackageSnapshot', () {
    test('round-trips complete package through JSON', () {
      final original = buildSnapshot();

      final decoded = OfflineTripPackageSnapshot.decode(original.encode());

      expect(decoded.schemaVersion, 1);
      expect(decoded.trip.tripId, 'trip-1');
      expect(decoded.trip.startName, 'Hà Nội');
      expect(decoded.trip.destinationName, 'Hà Giang');
      expect(decoded.route.distanceMeters, 300000);
      expect(decoded.route.points.length, 2);
      expect(decoded.pois.length, 1);
      expect(decoded.pois.single.typeKey, 'fuel');
      expect(decoded.connectivity, isNotNull);
      expect(decoded.connectivity!.proxyOnly, isTrue);
      expect(decoded.connectivity!.segments.length, 1);
    });

    test('preserves UTC dates', () {
      final decoded = OfflineTripPackageSnapshot.decode(
        buildSnapshot().encode(),
      );

      expect(decoded.savedAt.isUtc, isTrue);
      expect(decoded.trip.startAt!.isUtc, isTrue);
      expect(decoded.connectivity!.generatedAt!.isUtc, isTrue);
    });

    test('supports package without connectivity analysis', () {
      final original = buildSnapshot();

      final value = OfflineTripPackageSnapshot(
        schemaVersion: original.schemaVersion,
        savedAt: original.savedAt,
        trip: original.trip,
        route: original.route,
        pois: original.pois,
      );

      final decoded = OfflineTripPackageSnapshot.decode(value.encode());

      expect(decoded.connectivity, isNull);
    });

    test('rejects unsupported schema version', () {
      final encoded = buildSnapshot().encode().replaceFirst(
        '"schema_version":1',
        '"schema_version":99',
      );

      expect(
        () => OfflineTripPackageSnapshot.decode(encoded),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed package', () {
      expect(
        () => OfflineTripPackageSnapshot.decode('[]'),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => OfflineTripPackageSnapshot.decode('{"schema_version":1}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects malformed route points', () {
      final json = buildSnapshot().toJson();
      final route = Map<String, dynamic>.from(json['route'] as Map);
      route['points'] = 'invalid';
      json['route'] = route;

      expect(
        () => OfflineTripPackageSnapshot.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
