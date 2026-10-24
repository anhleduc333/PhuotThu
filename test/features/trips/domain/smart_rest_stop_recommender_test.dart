import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/rest_candidate_scorer.dart';
import 'package:phuotthu/features/trips/domain/rest_policy_calculator.dart';
import 'package:phuotthu/features/trips/domain/smart_rest_stop_recommender.dart';

void main() {
  const recommender = SmartRestStopRecommender();

  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  AlongRoutePlace restArea({
    required String id,
    required double longitude,
    double latitude = 0,
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

  AlongRoutePlace cafe({
    required String id,
    required double longitude,
    double latitude = 0,
  }) {
    return AlongRoutePlace(
      id: id,
      name: 'Cafe $id',
      type: AlongRoutePlaceType.food,
      latitude: latitude,
      longitude: longitude,
      source: 'test',
      sourceId: id,
      tags: const {'categories': 'catering.cafe'},
    );
  }

  AlongRoutePlace fuel({required String id, required double longitude}) {
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

  final longRoute = [routePoint(0, 0), routePoint(0, 2.7)];

  group('SmartRestStopRecommender', () {
    test('does not recommend rest stop for short trip', () {
      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        distanceMeters: 50000,
        durationSeconds: 60 * 60,
        places: const [],
      );

      expect(plan, isNotNull);

      expect(plan!.restRequired, isFalse);

      expect(plan.allTargetsCovered, isTrue);

      expect(plan.recommendations, isEmpty);
    });

    test('selects best POI for a rest target', () {
      const policy = RestPolicy(
        driveIntervalMinutes: 1000,
        distanceIntervalKm: 100,
      );

      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.35)],
        distanceMeters: 150000,
        durationSeconds: 3 * 60 * 60,
        restPolicy: policy,
        places: [
          restArea(id: 'far', longitude: 0.80),
          cafe(id: 'near', longitude: 0.90),
        ],
      );

      expect(plan, isNotNull);

      expect(plan!.restRequired, isTrue);

      expect(plan.recommendations.length, 1);

      expect(plan.recommendations.first.place.sourceId, 'near');

      expect(plan.allTargetsCovered, isTrue);
    });

    test('builds recommendations for multiple rest targets', () {
      final plan = recommender.recommend(
        routePoints: longRoute,
        distanceMeters: 300000,
        durationSeconds: 6 * 60 * 60,
        places: [
          cafe(id: 'stop-1', longitude: 0.67),
          restArea(id: 'stop-2', longitude: 1.35),
          cafe(id: 'stop-3', longitude: 2.02),
        ],
      );

      expect(plan, isNotNull);

      expect(plan!.restRequired, isTrue);

      expect(plan.restPlan.targets.length, 3);

      expect(plan.recommendations.length, 3);

      expect(plan.recommendations[0].place.sourceId, 'stop-1');

      expect(plan.recommendations[1].place.sourceId, 'stop-2');

      expect(plan.recommendations[2].place.sourceId, 'stop-3');

      expect(plan.allTargetsCovered, isTrue);
    });

    test('reports uncovered rest target when no candidate exists', () {
      final plan = recommender.recommend(
        routePoints: longRoute,
        distanceMeters: 300000,
        durationSeconds: 6 * 60 * 60,
        places: [
          cafe(id: 'stop-1', longitude: 0.67),
          cafe(id: 'stop-3', longitude: 2.02),
        ],
      );

      expect(plan, isNotNull);

      expect(plan!.restRequired, isTrue);

      expect(plan.allTargetsCovered, isFalse);

      expect(plan.recommendations.length, 2);

      expect(plan.uncoveredTargets.length, 1);

      expect(plan.uncoveredTargets.first.stopNumber, 2);
    });

    test('does not reuse same POI for multiple targets', () {
      const policy = RestPolicy(
        driveIntervalMinutes: 1000,
        distanceIntervalKm: 30,
        minimumRemainingDistanceKm: 5,
      );

      const scoringPolicy = RestCandidateScoringPolicy(
        maxTargetDistanceMeters: 40000,
      );

      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        distanceMeters: 110000,
        durationSeconds: 3 * 60 * 60,
        restPolicy: policy,
        scoringPolicy: scoringPolicy,
        places: [
          restArea(id: 'same', longitude: 0.27),
          restArea(id: 'second', longitude: 0.55),
          restArea(id: 'third', longitude: 0.82),
        ],
      );

      expect(plan, isNotNull);

      final ids = plan!.recommendations
          .map((item) => item.place.sourceId)
          .toList();

      expect(ids.toSet().length, ids.length);
    });

    test('keeps recommendations in forward route order', () {
      const policy = RestPolicy(
        driveIntervalMinutes: 1000,
        distanceIntervalKm: 50,
        minimumRemainingDistanceKm: 10,
      );

      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.8)],
        distanceMeters: 200000,
        durationSeconds: 4 * 60 * 60,
        restPolicy: policy,
        places: [
          restArea(id: 'A', longitude: 0.45),
          restArea(id: 'B', longitude: 0.90),
          restArea(id: 'C', longitude: 1.35),
        ],
      );

      expect(plan, isNotNull);

      final recommendations = plan!.recommendations;

      for (var i = 1; i < recommendations.length; i++) {
        expect(
          recommendations[i].candidate.progress.distanceFromStartMeters,
          greaterThan(
            recommendations[i - 1].candidate.progress.distanceFromStartMeters,
          ),
        );
      }
    });

    test('ignores non-rest POIs', () {
      const policy = RestPolicy(
        driveIntervalMinutes: 1000,
        distanceIntervalKm: 100,
      );

      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1.35)],
        distanceMeters: 150000,
        durationSeconds: 3 * 60 * 60,
        restPolicy: policy,
        places: [fuel(id: 'fuel', longitude: 0.90)],
      );

      expect(plan, isNotNull);

      expect(plan!.restRequired, isTrue);

      expect(plan.recommendations, isEmpty);

      expect(plan.allTargetsCovered, isFalse);
    });

    test('returns null for invalid route', () {
      final plan = recommender.recommend(
        routePoints: const [],
        distanceMeters: 100000,
        durationSeconds: 7200,
        places: const [],
      );

      expect(plan, isNull);
    });

    test('returns null when policy calculation is invalid', () {
      const invalidPolicy = RestPolicy(driveIntervalMinutes: 0);

      final plan = recommender.recommend(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        distanceMeters: 100000,
        durationSeconds: 7200,
        places: const [],
        restPolicy: invalidPolicy,
      );

      expect(plan, isNull);
    });
  });
}
