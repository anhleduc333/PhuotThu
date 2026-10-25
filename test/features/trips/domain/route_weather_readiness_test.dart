import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/route_weather_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';

void main() {
  const evaluator = RouteWeatherReadinessEvaluator();

  ConnectivityRiskAssessment connectivity({
    double totalRouteMeters = 100000,
    double warningEndMeters = 10000,
    DateTime? generatedAt,
  }) {
    return ConnectivityRiskAssessment(
      totalRouteMeters: totalRouteMeters,
      overallRiskScore: 0.4,
      overallLevel: ConnectivityRiskLevel.moderate,
      generatedAt: generatedAt,
      segments: [
        ConnectivityRiskSegment(
          startDistanceMeters: 0,
          endDistanceMeters: warningEndMeters,
          startProgressRatio: 0,
          endProgressRatio: warningEndMeters / totalRouteMeters,
          averageRiskScore: 0.8,
          maxRiskScore: 0.9,
          level: ConnectivityRiskLevel.high,
          sampleCount: 2,
        ),
        ConnectivityRiskSegment(
          startDistanceMeters: warningEndMeters,
          endDistanceMeters: totalRouteMeters,
          startProgressRatio: warningEndMeters / totalRouteMeters,
          endProgressRatio: 1,
          averageRiskScore: 0.2,
          maxRiskScore: 0.3,
          level: ConnectivityRiskLevel.low,
          sampleCount: 4,
        ),
      ],
    );
  }

  group('RouteWeatherReadinessEvaluator', () {
    test('no route makes route review a blocking missing item', () {
      final result = evaluator.evaluate(hasRoute: false);

      final routeItem = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.routeReviewed,
      );

      expect(result.hasRoute, isFalse);
      expect(routeItem.status, TripReadinessItemStatus.missing);
      expect(routeItem.blocksReadiness, isTrue);
      expect(routeItem.isRequired, isTrue);
    });

    test('valid route starts as unchecked until user reviews it', () {
      final result = evaluator.evaluate(hasRoute: true);

      final routeItem = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.routeReviewed,
      );

      expect(routeItem.status, TripReadinessItemStatus.unknown);
      expect(routeItem.source, TripReadinessSourceType.manual);
      expect(routeItem.preventsReady, isTrue);
    });

    test('route can be confirmed ready', () {
      final result = evaluator.evaluate(
        hasRoute: true,
        confirmations: const RouteWeatherReadinessConfirmations(
          routeReviewed: true,
        ),
      );

      final routeItem = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.routeReviewed,
      );

      expect(routeItem.status, TripReadinessItemStatus.ready);
    });

    test('route requiring review becomes needs attention', () {
      final result = evaluator.evaluate(
        hasRoute: true,
        confirmations: const RouteWeatherReadinessConfirmations(
          routeReviewed: false,
        ),
      );

      final routeItem = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.routeReviewed,
      );

      expect(routeItem.status, TripReadinessItemStatus.needsAttention);
      expect(routeItem.blocksReadiness, isFalse);
      expect(routeItem.preventsReady, isTrue);
    });

    test('weather remains manual and unchecked by default', () {
      final result = evaluator.evaluate(hasRoute: true);

      final weatherItem = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.weatherReviewed,
      );

      expect(weatherItem.status, TripReadinessItemStatus.unknown);
      expect(weatherItem.source, TripReadinessSourceType.weather);
    });

    test('weather confirmation can be ready or needs attention', () {
      final ready = evaluator.evaluate(
        hasRoute: true,
        confirmations: const RouteWeatherReadinessConfirmations(
          weatherReviewed: true,
        ),
      );

      final attention = evaluator.evaluate(
        hasRoute: true,
        confirmations: const RouteWeatherReadinessConfirmations(
          weatherReviewed: false,
        ),
      );

      expect(
        ready.items
            .singleWhere(
              (item) => item.type == TripReadinessItemType.weatherReviewed,
            )
            .status,
        TripReadinessItemStatus.ready,
      );

      expect(
        attention.items
            .singleWhere(
              (item) => item.type == TripReadinessItemType.weatherReviewed,
            )
            .status,
        TripReadinessItemStatus.needsAttention,
      );
    });

    test('no connectivity assessment stays unchecked', () {
      final result = evaluator.evaluate(hasRoute: true);

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.connectivityReviewed,
      );

      expect(result.hasConnectivityAssessment, isFalse);
      expect(item.status, TripReadinessItemStatus.unknown);
      expect(item.preventsReady, isTrue);
    });

    test('valid connectivity assessment becomes ready automatically', () {
      final result = evaluator.evaluate(
        hasRoute: true,
        connectivityAssessment: connectivity(),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.connectivityReviewed,
      );

      expect(result.hasConnectivityAssessment, isTrue);
      expect(item.status, TripReadinessItemStatus.ready);
      expect(result.connectivityWarningRoutePercent, closeTo(10, 0.0001));
    });

    test('empty connectivity assessment is not considered reviewed', () {
      const emptyAssessment = ConnectivityRiskAssessment(
        totalRouteMeters: 100000,
        overallRiskScore: 0.2,
        overallLevel: ConnectivityRiskLevel.low,
        segments: [],
        sampledPoints: [],
      );

      final result = evaluator.evaluate(
        hasRoute: true,
        connectivityAssessment: emptyAssessment,
      );

      expect(result.hasConnectivityAssessment, isFalse);

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.connectivityReviewed,
      );

      expect(item.status, TripReadinessItemStatus.unknown);
    });

    test('connectivity item uses generatedAt in UTC', () {
      final generatedAt = DateTime.parse('2026-10-25T11:30:00+07:00');

      final result = evaluator.evaluate(
        hasRoute: true,
        connectivityAssessment: connectivity(generatedAt: generatedAt),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.connectivityReviewed,
      );

      expect(item.lastCheckedAt, isNotNull);
      expect(item.lastCheckedAt!.isUtc, isTrue);
      expect(item.lastCheckedAt!.hour, 4);
      expect(item.lastCheckedAt!.minute, 30);
    });

    test('manual confirmation timestamp is normalized to UTC', () {
      final checkedAt = DateTime.parse('2026-10-25T12:00:00+07:00');

      final result = evaluator.evaluate(
        hasRoute: true,
        confirmations: RouteWeatherReadinessConfirmations(
          routeReviewed: true,
          weatherReviewed: true,
          checkedAt: checkedAt,
        ),
      );

      final route = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.routeReviewed,
      );

      final weather = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.weatherReviewed,
      );

      expect(route.lastCheckedAt!.isUtc, isTrue);
      expect(weather.lastCheckedAt!.isUtc, isTrue);
      expect(route.lastCheckedAt!.hour, 5);
    });

    test(
      'all required ready when route, weather and connectivity are ready',
      () {
        final result = evaluator.evaluate(
          hasRoute: true,
          connectivityAssessment: connectivity(),
          confirmations: const RouteWeatherReadinessConfirmations(
            routeReviewed: true,
            weatherReviewed: true,
          ),
        );

        expect(result.readyCount, 3);
        expect(result.allRequiredReady, isTrue);
        expect(result.actionItems, isEmpty);
        expect(result.uncheckedItems, isEmpty);
      },
    );

    test('all items belong to route category', () {
      final result = evaluator.evaluate(hasRoute: true);

      expect(
        result.items.every(
          (item) => item.category == TripReadinessCategory.route,
        ),
        isTrue,
      );
    });

    test('confirmation completeness requires route and weather answers', () {
      const empty = RouteWeatherReadinessConfirmations();

      const partial = RouteWeatherReadinessConfirmations(routeReviewed: true);

      const complete = RouteWeatherReadinessConfirmations(
        routeReviewed: true,
        weatherReviewed: false,
      );

      expect(empty.isComplete, isFalse);
      expect(partial.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });
  });
}
