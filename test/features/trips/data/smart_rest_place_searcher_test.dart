import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/data/along_route_service.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/along_route_result.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/data/smart_rest_place_searcher.dart';
import 'package:phuotthu/features/trips/domain/rest_policy_calculator.dart';

void main() {
  const searcher = SmartRestPlaceSearcher();

  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  RestTarget target(int stopNumber, double distanceMeters) {
    return RestTarget(
      stopNumber: stopNumber,
      trigger: RestTrigger.distance,
      progressRatio: 0.5,
      targetDistanceMeters: distanceMeters,
      targetElapsedSeconds: 5400,
      suggestedRestMinutes: 15,
    );
  }

  AlongRoutePlace restPlace({
    required String id,
    required double longitude,
    double? distanceFromRouteMeters,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Rest $id',
      type: AlongRoutePlaceType.restArea,
      latitude: 0,
      longitude: longitude,
      source: 'test',
      sourceId: id,
      distanceFromRouteMeters: distanceFromRouteMeters,
    );
  }

  AlongRoutePlace foodPlace({required String id, required double longitude}) {
    return AlongRoutePlace(
      id: id,
      name: 'Food $id',
      type: AlongRoutePlaceType.food,
      latitude: 0,
      longitude: longitude,
      source: 'test',
      sourceId: id,
      tags: const {'categories': 'catering.cafe'},
    );
  }

  AlongRoutePlace fuelPlace({required String id, required double longitude}) {
    return AlongRoutePlace(
      id: id,
      name: 'Fuel $id',
      type: AlongRoutePlaceType.fuel,
      latitude: 0,
      longitude: longitude,
      source: 'test',
      sourceId: id,
    );
  }

  final route = [
    routePoint(0, 0),
    routePoint(0, 0.5),
    routePoint(0, 1.0),
    routePoint(0, 1.5),
    routePoint(0, 2.0),
    routePoint(0, 2.5),
    routePoint(0, 3.0),
  ];

  group('SmartRestPlaceSearcher', () {
    test('searches once for each rest target', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [
          restPlace(id: 'rest-$call', longitude: routePoints.last.longitude),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 80000), target(2, 160000), target(3, 240000)],
      );

      expect(result.targetCount, 3);
      expect(result.successfulTargets, 3);
      expect(result.failedTargets, 0);
      expect(service.callCount, 3);
      expect(result.places.length, 3);

      for (final types in service.requestedTypes) {
        expect(types, const {
          AlongRoutePlaceType.restArea,
          AlongRoutePlaceType.food,
        });
      }
    });

    test('accepts both rest areas and food places', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [
          restPlace(id: 'rest', longitude: 1),
          foodPlace(id: 'cafe', longitude: 1),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 110000)],
      );

      expect(result.places.length, 2);
      expect(result.places.map((place) => place.type).toSet(), {
        AlongRoutePlaceType.restArea,
        AlongRoutePlaceType.food,
      });
    });

    test('ignores unrelated POI types', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [
          restPlace(id: 'rest', longitude: 1),
          fuelPlace(id: 'fuel', longitude: 1),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 110000)],
      );

      expect(result.places.length, 1);
      expect(result.places.single.sourceId, 'rest');
    });

    test('respects rest-area-only filter', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [
          restPlace(id: 'rest', longitude: 1),
          foodPlace(id: 'food', longitude: 1),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 110000)],
        types: const {AlongRoutePlaceType.restArea},
      );

      expect(service.callCount, 1);
      expect(service.requestedTypes.single, const {
        AlongRoutePlaceType.restArea,
      });
      expect(result.places.length, 1);
      expect(result.places.single.type, AlongRoutePlaceType.restArea);
    });

    test('respects food-only filter', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [
          restPlace(id: 'rest', longitude: 1),
          foodPlace(id: 'food', longitude: 1),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 110000)],
        types: const {AlongRoutePlaceType.food},
      );

      expect(service.callCount, 1);
      expect(service.requestedTypes.single, const {AlongRoutePlaceType.food});
      expect(result.places.length, 1);
      expect(result.places.single.type, AlongRoutePlaceType.food);
    });

    test('does not search when no eligible rest type is requested', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [fuelPlace(id: 'fuel', longitude: 1)],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 110000)],
        types: const {AlongRoutePlaceType.fuel},
      );

      expect(service.callCount, 0);
      expect(result.targetCount, 0);
      expect(result.places, isEmpty);
    });

    test('deduplicates overlapping target results', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => [
          restPlace(
            id: 'shared',
            longitude: 1,
            distanceFromRouteMeters: call == 1 ? 400 : 80,
          ),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 100000), target(2, 120000)],
      );

      expect(result.places.length, 1);
      expect(result.places.single.sourceId, 'shared');
      expect(result.places.single.distanceFromRouteMeters, 80);
    });

    test('keeps successful targets when another search fails', () async {
      final service = _FakeAlongRouteService(
        failingCalls: const {2},
        onSearch: (call, routePoints) => [
          restPlace(id: 'rest-$call', longitude: routePoints.last.longitude),
        ],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 80000), target(2, 160000), target(3, 240000)],
      );

      expect(result.targetCount, 3);
      expect(result.successfulTargets, 2);
      expect(result.failedTargets, 1);
      expect(result.hasPartialFailures, isTrue);
      expect(result.allTargetSearchesFailed, isFalse);
      expect(result.places.length, 2);
    });

    test('reports when every target search fails', () async {
      final service = _FakeAlongRouteService(
        failEveryCall: true,
        onSearch: (call, routePoints) => const [],
      );

      final result = await searcher.search(
        service: service,
        routePoints: route,
        targets: [target(1, 80000), target(2, 160000)],
      );

      expect(result.successfulTargets, 0);
      expect(result.failedTargets, 2);
      expect(result.allTargetSearchesFailed, isTrue);
      expect(result.places, isEmpty);
    });

    test('does not call provider for invalid input', () async {
      final service = _FakeAlongRouteService(
        onSearch: (call, routePoints) => const [],
      );

      final noTargetResult = await searcher.search(
        service: service,
        routePoints: route,
        targets: const [],
      );

      final invalidRouteResult = await searcher.search(
        service: service,
        routePoints: [routePoint(0, 0)],
        targets: [target(1, 10000)],
      );

      expect(noTargetResult.targetCount, 0);
      expect(invalidRouteResult.targetCount, 0);
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
