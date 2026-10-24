import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/rest_candidate_scorer.dart';
import 'package:phuotthu/features/trips/domain/rest_policy_calculator.dart';

void main() {
  const scorer = RestCandidateScorer();

  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  RestTarget targetAt100Km() {
    return const RestTarget(
      stopNumber: 1,
      trigger: RestTrigger.distance,
      progressRatio: 0.45,
      targetDistanceMeters: 100000,
      targetElapsedSeconds: 5400,
      suggestedRestMinutes: 15,
    );
  }

  AlongRoutePlace restArea({
    required String id,
    required double latitude,
    required double longitude,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Rest $id',
      type: AlongRoutePlaceType.restArea,
      latitude: latitude,
      longitude: longitude,
      source: 'test',
      sourceId: id,
    );
  }

  AlongRoutePlace food({
    required String id,
    required double latitude,
    required double longitude,
    String categories = '',
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Food $id',
      type: AlongRoutePlaceType.food,
      latitude: latitude,
      longitude: longitude,
      source: 'test',
      sourceId: id,
      tags: {if (categories.isNotEmpty) 'categories': categories},
    );
  }

  AlongRoutePlace fuel({
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

  final route = [routePoint(0, 0), routePoint(0, 2)];

  group('RestCandidateScorer', () {
    test('prefers place closer to rest target', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [
          restArea(id: 'far', latitude: 0, longitude: 0.80),
          restArea(id: 'near', latitude: 0, longitude: 0.90),
        ],
      );

      expect(result.length, 2);

      expect(result.first.place.sourceId, 'near');

      expect(result.first.score.total, greaterThan(result[1].score.total));
    });

    test('prefers lower route deviation when route position is similar', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [
          restArea(id: 'off-route', latitude: 0.01, longitude: 0.90),
          restArea(id: 'on-route', latitude: 0, longitude: 0.90),
        ],
      );

      expect(result.length, 2);

      expect(result.first.place.sourceId, 'on-route');

      expect(
        result.first.progress.distanceFromRouteMeters,
        lessThan(result[1].progress.distanceFromRouteMeters),
      );
    });

    test('prefers rest area over generic food when geometry is equal', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [
          food(id: 'food', latitude: 0, longitude: 0.90),
          restArea(id: 'rest', latitude: 0, longitude: 0.90),
        ],
      );

      expect(result.length, 2);

      expect(result.first.place.sourceId, 'rest');

      expect(result.first.score.placeSuitability, 1);
    });

    test('scores cafe higher than fast food at same location', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [
          food(
            id: 'fast-food',
            latitude: 0,
            longitude: 0.90,
            categories: 'catering.fast_food',
          ),
          food(
            id: 'cafe',
            latitude: 0,
            longitude: 0.90,
            categories: 'catering.cafe',
          ),
        ],
      );

      expect(result.length, 2);

      expect(result.first.place.sourceId, 'cafe');

      expect(result.first.score.placeSuitability, closeTo(0.95, 0.001));

      expect(result[1].score.placeSuitability, closeTo(0.70, 0.001));
    });

    test('ignores non-rest candidate types', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [fuel(id: 'fuel', latitude: 0, longitude: 0.90)],
      );

      expect(result, isEmpty);
    });

    test('ignores places outside route corridor', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [restArea(id: 'too-far', latitude: 0.05, longitude: 0.90)],
      );

      expect(result, isEmpty);
    });

    test('ignores places too far from target position', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [restArea(id: 'too-early', latitude: 0, longitude: 0.50)],
      );

      expect(result, isEmpty);
    });

    test('deduplicates places by source id', () {
      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        places: [
          restArea(id: 'same', latitude: 0, longitude: 0.89),
          restArea(id: 'same', latitude: 0, longitude: 0.90),
        ],
      );

      expect(result.length, 1);
    });

    test('respects max results', () {
      const policy = RestCandidateScoringPolicy(maxResults: 2);

      final result = scorer.score(
        target: targetAt100Km(),
        routePoints: route,
        policy: policy,
        places: [
          restArea(id: 'A', latitude: 0, longitude: 0.82),
          restArea(id: 'B', latitude: 0, longitude: 0.86),
          restArea(id: 'C', latitude: 0, longitude: 0.90),
        ],
      );

      expect(result.length, 2);
    });

    test('returns empty list for invalid inputs', () {
      expect(
        scorer.score(
          target: targetAt100Km(),
          routePoints: const [],
          places: [restArea(id: 'A', latitude: 0, longitude: 0.9)],
        ),
        isEmpty,
      );

      const invalidPolicy = RestCandidateScoringPolicy(maxResults: 0);

      expect(
        scorer.score(
          target: targetAt100Km(),
          routePoints: route,
          places: [restArea(id: 'A', latitude: 0, longitude: 0.9)],
          policy: invalidPolicy,
        ),
        isEmpty,
      );
    });
  });
}
