import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/fuel_range_calculator.dart';
import 'package:phuotthu/features/trips/domain/smart_fuel_stop_recommender.dart';

void main() {
  const recommender = SmartFuelStopRecommender();

  const fuelCalculator = FuelRangeCalculator();

  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  AlongRoutePlace fuelStation({
    required String id,
    required double latitude,
    required double longitude,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Fuel $id',
      type: AlongRoutePlaceType.fuel,
      latitude: latitude,
      longitude: longitude,
      source: 'test',
      sourceId: id,
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

  FuelRangeEstimate testFuelRange() {
    final result = fuelCalculator.calculate(
      tankCapacityLiters: 10,
      consumptionLitersPer100Km: 10,
      reserveRatio: 0.2,
    );

    return result!;
  }

  group('SmartFuelStopRecommender', () {
    test('does not recommend a stop when destination is within safe range', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        places: const [],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNotNull);

      expect(plan!.fuelStopRequired, isFalse);

      expect(plan.routeFullyCovered, isTrue);

      expect(plan.recommendations, isEmpty);
    });

    test('selects the farthest reachable fuel station before safe limit', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.2)],
        places: [
          fuelStation(id: 'A', latitude: 0, longitude: 0.3),
          fuelStation(id: 'B', latitude: 0, longitude: 0.7),
          fuelStation(id: 'C', latitude: 0, longitude: 0.9),
        ],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNotNull);

      expect(plan!.fuelStopRequired, isTrue);

      expect(plan.recommendations, isNotEmpty);

      expect(plan.recommendations.first.place.sourceId, 'B');

      expect(
        plan.recommendations.first.progress.distanceFromStartKm,
        closeTo(77.84, 0.5),
      );
    });

    test('builds multiple fuel stops for a long route', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 2)],
        places: [
          fuelStation(id: 'A', latitude: 0, longitude: 0.3),
          fuelStation(id: 'B', latitude: 0, longitude: 0.7),
          fuelStation(id: 'C', latitude: 0, longitude: 1.0),
          fuelStation(id: 'D', latitude: 0, longitude: 1.4),
          fuelStation(id: 'E', latitude: 0, longitude: 1.9),
        ],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNotNull);

      expect(plan!.fuelStopRequired, isTrue);

      expect(plan.routeFullyCovered, isTrue);

      expect(plan.recommendations.length, 2);

      expect(plan.recommendations[0].place.sourceId, 'B');

      expect(plan.recommendations[1].place.sourceId, 'D');

      expect(plan.recommendations[0].stopNumber, 1);

      expect(plan.recommendations[1].stopNumber, 2);
    });

    test('reports incomplete plan when no reachable fuel station exists', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 2)],
        places: [fuelStation(id: 'TooFar', latitude: 0, longitude: 0.9)],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNotNull);

      expect(plan!.fuelStopRequired, isTrue);

      expect(plan.routeFullyCovered, isFalse);

      expect(plan.recommendations, isEmpty);

      expect(plan.uncoveredFromMeters, closeTo(0, 1));
    });

    test('ignores non-fuel places', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.2)],
        places: [foodPlace(id: 'Food', latitude: 0, longitude: 0.7)],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNotNull);

      expect(plan!.routeFullyCovered, isFalse);

      expect(plan.recommendations, isEmpty);
    });

    test('ignores fuel stations outside route corridor', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.2)],
        places: [
          fuelStation(id: 'FarFromRoute', latitude: 0.05, longitude: 0.7),
        ],
        fuelRange: testFuelRange(),
        maxCorridorMeters: 2000,
      );

      expect(plan, isNotNull);

      expect(plan!.routeFullyCovered, isFalse);

      expect(plan.recommendations, isEmpty);
    });

    test('uses full tank safe range after recommended refuel', () {
      final partialRange = fuelCalculator.calculate(
        tankCapacityLiters: 10,
        consumptionLitersPer100Km: 10,
        startingFuelRatio: 0.6,
        reserveRatio: 0.2,
      )!;

      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        places: [fuelStation(id: 'A', latitude: 0, longitude: 0.35)],
        fuelRange: partialRange,
      );

      expect(plan, isNotNull);

      expect(plan!.initialSafeRangeKm, closeTo(40, 0.01));

      expect(plan.fullTankSafeRangeKm, closeTo(80, 0.01));

      expect(plan.recommendations.length, 1);

      expect(plan.recommendations.first.place.sourceId, 'A');

      expect(plan.routeFullyCovered, isTrue);
    });

    test('deduplicates places with the same source id', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.2)],
        places: [
          fuelStation(id: 'Same', latitude: 0, longitude: 0.3),
          fuelStation(id: 'Same', latitude: 0, longitude: 0.7),
        ],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNotNull);

      expect(plan!.recommendations.length, lessThanOrEqualTo(1));
    });

    test('returns null for invalid route', () {
      final plan = recommender.recommend(
        routePoints: const [],
        places: const [],
        fuelRange: testFuelRange(),
      );

      expect(plan, isNull);
    });

    test('returns null for invalid corridor', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        places: const [],
        fuelRange: testFuelRange(),
        maxCorridorMeters: -1,
      );

      expect(plan, isNull);
    });
  });
}
