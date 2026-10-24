import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/data/offline_trip_package_builder.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';

void main() {
  const builder = OfflineTripPackageBuilder();

  List<RoutePoint> routePoints() {
    return const [
      RoutePoint(latitude: 21, longitude: 105),
      RoutePoint(latitude: 21.5, longitude: 105.5),
      RoutePoint(latitude: 22, longitude: 106),
    ];
  }

  AlongRoutePlace poi({
    required String id,
    required String sourceId,
    required AlongRoutePlaceType type,
    double? distanceFromRouteMeters,
    double latitude = 21.5,
    double longitude = 105.5,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'POI $id',
      type: type,
      latitude: latitude,
      longitude: longitude,
      source: 'geoapify',
      sourceId: sourceId,
      address: 'Địa chỉ $id',
      phone: '0123',
      website: 'https://example.com',
      distanceFromRouteMeters: distanceFromRouteMeters,
    );
  }

  test('builds trip and route snapshots', () {
    final savedAt = DateTime.utc(2026, 10, 25, 3);

    final result = builder.build(
      tripId: ' trip-1 ',
      startName: ' Hà Nội ',
      destinationName: ' Hà Giang ',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 300000,
      routeDurationSeconds: 21600,
      routePoints: routePoints(),
      vehicleId: ' vehicle-1 ',
      plannedStartAt: DateTime.utc(2026, 11, 1),
      budgetTotal: 3000000,
      savedAt: savedAt,
    );

    expect(result.trip.tripId, 'trip-1');
    expect(result.trip.startName, 'Hà Nội');
    expect(result.trip.destinationName, 'Hà Giang');
    expect(result.trip.vehicleId, 'vehicle-1');
    expect(result.route.distanceMeters, 300000);
    expect(result.route.durationSeconds, 21600);
    expect(result.route.points.length, 3);
    expect(result.savedAt, savedAt);
  });

  test('deduplicates POIs and keeps nearer duplicate', () {
    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      pois: [
        poi(
          id: 'far',
          sourceId: 'same',
          type: AlongRoutePlaceType.fuel,
          distanceFromRouteMeters: 900,
        ),
        poi(
          id: 'near',
          sourceId: 'same',
          type: AlongRoutePlaceType.fuel,
          distanceFromRouteMeters: 100,
        ),
      ],
    );

    expect(result.pois.length, 1);
    expect(result.pois.single.id, 'near');
    expect(result.pois.single.distanceFromRouteMeters, 100);
  });

  test('maps stable POI type keys', () {
    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      pois: [
        poi(
          id: 'fuel',
          sourceId: '1',
          type: AlongRoutePlaceType.fuel,
          distanceFromRouteMeters: 100,
        ),
        poi(
          id: 'rest',
          sourceId: '2',
          type: AlongRoutePlaceType.restArea,
          distanceFromRouteMeters: 200,
        ),
        poi(
          id: 'food',
          sourceId: '3',
          type: AlongRoutePlaceType.food,
          distanceFromRouteMeters: 300,
        ),
        poi(
          id: 'repair',
          sourceId: '4',
          type: AlongRoutePlaceType.repair,
          distanceFromRouteMeters: 400,
        ),
        poi(
          id: 'medical',
          sourceId: '5',
          type: AlongRoutePlaceType.medical,
          distanceFromRouteMeters: 500,
        ),
      ],
    );

    expect(result.pois.map((item) => item.typeKey).toList(), [
      'fuel',
      'accommodation',
      'food',
      'repair',
      'medical',
    ]);
  });

  test('sorts POIs by distance from route', () {
    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      pois: [
        poi(
          id: 'far',
          sourceId: 'far',
          type: AlongRoutePlaceType.food,
          distanceFromRouteMeters: 800,
        ),
        poi(
          id: 'near',
          sourceId: 'near',
          type: AlongRoutePlaceType.food,
          distanceFromRouteMeters: 100,
        ),
      ],
    );

    expect(result.pois.map((item) => item.id).toList(), ['near', 'far']);
  });

  test('stores connectivity assessment', () {
    final assessment = ConnectivityRiskAssessment(
      totalRouteMeters: 100000,
      overallRiskScore: 0.7,
      overallLevel: ConnectivityRiskLevel.high,
      generatedAt: DateTime.utc(2026, 10, 25, 2),
      segments: const [
        ConnectivityRiskSegment(
          startDistanceMeters: 20000,
          endDistanceMeters: 50000,
          startProgressRatio: 0.2,
          endProgressRatio: 0.5,
          averageRiskScore: 0.7,
          maxRiskScore: 0.8,
          level: ConnectivityRiskLevel.high,
        ),
      ],
    );

    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      connectivityAssessment: assessment,
      connectivityProxyOnly: true,
    );

    expect(result.connectivity, isNotNull);
    expect(result.connectivity!.overallLevelKey, 'high');
    expect(result.connectivity!.proxyOnly, isTrue);
    expect(result.connectivity!.warningRoutePercent, 30);
    expect(result.connectivity!.segments.length, 1);
  });

  test('omits connectivity when assessment has no data', () {
    const assessment = ConnectivityRiskAssessment(
      totalRouteMeters: 100000,
      overallRiskScore: 0,
      overallLevel: ConnectivityRiskLevel.unknown,
      segments: [],
    );

    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      connectivityAssessment: assessment,
    );

    expect(result.connectivity, isNull);
  });

  test('filters invalid POI coordinates', () {
    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      pois: [
        poi(id: 'valid', sourceId: '1', type: AlongRoutePlaceType.medical),
        poi(
          id: 'invalid',
          sourceId: '2',
          type: AlongRoutePlaceType.medical,
          latitude: 120,
        ),
      ],
    );

    expect(result.pois.length, 1);
    expect(result.pois.single.id, 'valid');
  });

  test('normalizes invalid optional budget to null', () {
    final result = builder.build(
      tripId: 'trip-1',
      startName: 'A',
      destinationName: 'B',
      startLatitude: 21,
      startLongitude: 105,
      destinationLatitude: 22,
      destinationLongitude: 106,
      routeDistanceMeters: 100000,
      routeDurationSeconds: 7200,
      routePoints: routePoints(),
      budgetTotal: -1,
    );

    expect(result.trip.budgetTotal, isNull);
  });

  test('rejects invalid required trip and route data', () {
    expect(
      () => builder.build(
        tripId: ' ',
        startName: 'A',
        destinationName: 'B',
        startLatitude: 21,
        startLongitude: 105,
        destinationLatitude: 22,
        destinationLongitude: 106,
        routeDistanceMeters: 100000,
        routeDurationSeconds: 7200,
        routePoints: routePoints(),
      ),
      throwsArgumentError,
    );

    expect(
      () => builder.build(
        tripId: 'trip-1',
        startName: 'A',
        destinationName: 'B',
        startLatitude: 21,
        startLongitude: 105,
        destinationLatitude: 22,
        destinationLongitude: 106,
        routeDistanceMeters: 0,
        routeDurationSeconds: 7200,
        routePoints: routePoints(),
      ),
      throwsArgumentError,
    );
  });
}
