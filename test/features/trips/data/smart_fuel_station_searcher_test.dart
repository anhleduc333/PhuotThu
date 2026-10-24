import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/data/along_route_service.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/along_route_result.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/data/smart_fuel_station_searcher.dart';

void main() {
  const searcher = SmartFuelStationSearcher();

  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  AlongRoutePlace fuelPlace({
    required String id,
    required double latitude,
    required double longitude,
    double? distanceFromRouteMeters,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Fuel $id',
      type: AlongRoutePlaceType.fuel,
      latitude: latitude,
      longitude: longitude,
      source: 'test',
      sourceId: id,
      distanceFromRouteMeters: distanceFromRouteMeters,
    );
  }

  AlongRoutePlace foodPlace({
    required String id,
    required double latitude,
    required double longitude,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Food $id',
      type: AlongRoutePlaceType.food,
      latitude: latitude,
      longitude: longitude,
      source: 'test',
      sourceId: id,
    );
  }

  group('SmartFuelStationSearcher', () {
    test('uses one segment for a short route', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) {
          return [fuelPlace(id: 'A', latitude: 0, longitude: 0.2)];
        },
      );

      final result = await searcher.search(
        service: service,
        routePoints: [routePoint(0, 0), routePoint(0, 0.4)],
        safeRangeMeters: 170000,
      );

      expect(result.segmentCount, 1);
      expect(result.successfulSegments, 1);
      expect(result.failedSegments, 0);
      expect(result.places.length, 1);
      expect(service.callCount, 1);
      expect(service.requestedTypes.single, const {AlongRoutePlaceType.fuel});
    });

    test('splits a long route into multiple segment searches', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) {
          final first = routePoints.first;
          final last = routePoints.last;

          return [
            fuelPlace(
              id: 'station-$call',
              latitude: (first.latitude + last.latitude) / 2,
              longitude: (first.longitude + last.longitude) / 2,
            ),
          ];
        },
      );

      final result = await searcher.search(
        service: service,
        routePoints: [
          routePoint(0, 0),
          routePoint(0, 0.5),
          routePoint(0, 1.0),
          routePoint(0, 1.5),
          routePoint(0, 2.0),
          routePoint(0, 2.5),
          routePoint(0, 3.0),
        ],
        safeRangeMeters: 170000,
      );

      expect(result.segmentCount, greaterThan(1));
      expect(result.successfulSegments, result.segmentCount);
      expect(result.failedSegments, 0);
      expect(service.callCount, result.segmentCount);
      expect(result.places.length, result.segmentCount);
    });

    test('deduplicates stations returned by overlapping segments', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) {
          return [
            fuelPlace(
              id: 'shared',
              latitude: 0,
              longitude: 1,
              distanceFromRouteMeters: call == 1 ? 400 : 100,
            ),
            fuelPlace(
              id: 'unique-$call',
              latitude: 0,
              longitude: routePoints.last.longitude,
            ),
          ];
        },
      );

      final result = await searcher.search(
        service: service,
        routePoints: [
          routePoint(0, 0),
          routePoint(0, 1),
          routePoint(0, 2),
          routePoint(0, 3),
        ],
        safeRangeMeters: 170000,
      );

      final shared = result.places.singleWhere(
        (place) => place.sourceId == 'shared',
      );

      expect(
        result.places.where((place) => place.sourceId == 'shared').length,
        1,
      );
      expect(shared.distanceFromRouteMeters, 100);
    });

    test('ignores non-fuel places from provider response', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) {
          return [
            fuelPlace(id: 'fuel', latitude: 0, longitude: 0.2),
            foodPlace(id: 'food', latitude: 0, longitude: 0.2),
          ];
        },
      );

      final result = await searcher.search(
        service: service,
        routePoints: [routePoint(0, 0), routePoint(0, 0.4)],
        safeRangeMeters: 170000,
      );

      expect(result.places.length, 1);
      expect(result.places.single.type, AlongRoutePlaceType.fuel);
    });

    test('keeps successful data when one segment fails', () async {
      final service = _FakeAlongRouteService(
        failingCalls: const {2},
        onSearch: (call, routePoints) {
          return [
            fuelPlace(
              id: 'station-$call',
              latitude: 0,
              longitude: routePoints.last.longitude,
            ),
          ];
        },
      );

      final result = await searcher.search(
        service: service,
        routePoints: [
          routePoint(0, 0),
          routePoint(0, 1),
          routePoint(0, 2),
          routePoint(0, 3),
        ],
        safeRangeMeters: 170000,
      );

      expect(result.segmentCount, greaterThan(1));
      expect(result.failedSegments, 1);
      expect(result.successfulSegments, result.segmentCount - 1);
      expect(result.hasPartialFailures, isTrue);
      expect(result.allSegmentsFailed, isFalse);
      expect(result.places, isNotEmpty);
    });

    test('reports all segment failures without throwing', () async {
      final service = _FakeAlongRouteService(
        failEveryCall: true,
        onSearch: (call, routePoints) => const [],
      );

      final result = await searcher.search(
        service: service,
        routePoints: [
          routePoint(0, 0),
          routePoint(0, 1),
          routePoint(0, 2),
          routePoint(0, 3),
        ],
        safeRangeMeters: 170000,
      );

      expect(result.segmentCount, greaterThan(1));
      expect(result.successfulSegments, 0);
      expect(result.failedSegments, result.segmentCount);
      expect(result.allSegmentsFailed, isTrue);
      expect(result.places, isEmpty);
    });

    test('returns empty result for an invalid route', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => const [],
      );

      final result = await searcher.search(
        service: service,
        routePoints: [routePoint(0, 0)],
        safeRangeMeters: 170000,
      );

      expect(result.segmentCount, 0);
      expect(result.successfulSegments, 0);
      expect(result.failedSegments, 0);
      expect(result.places, isEmpty);
      expect(service.callCount, 0);
    });
  });
}

typedef _SearchHandler = List<AlongRoutePlace> Function(
  int call,
  List<RoutePoint> routePoints,
);

class _FakeAlongRouteService implements AlongRouteService {
  _FakeAlongRouteService({
    required this.onSearch,
    this.failingCalls = const {},
    this.failEveryCall = false,
  });

  final _SearchHandler onSearch;
  final Set<int> failingCalls;
  final bool failEveryCall;

  int callCount = 0;
  final List<Set<AlongRoutePlaceType>> requestedTypes = [];

  @override
  Future<AlongRouteResult> search({
    required List<RoutePoint> routePoints,
    Set<AlongRoutePlaceType> types = const {
      AlongRoutePlaceType.fuel,
      AlongRoutePlaceType.restArea,
      AlongRoutePlaceType.food,
      AlongRoutePlaceType.repair,
      AlongRoutePlaceType.medical,
    },
    double searchRadiusMeters = 3000,
    int maxResults = 50,
  }) async {
    callCount++;
    requestedTypes.add(Set<AlongRoutePlaceType>.from(types));

    if (failEveryCall || failingCalls.contains(callCount)) {
      throw StateError('Synthetic provider failure');
    }

    return AlongRouteResult(
      places: onSearch(callCount, routePoints),
      provider: 'fake',
      searchedPointCount: routePoints.length,
    );
  }
}
