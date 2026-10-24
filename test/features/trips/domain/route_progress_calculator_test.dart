import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/route_progress_calculator.dart';

void main() {
  const calculator = RouteProgressCalculator();

  RoutePoint point(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  group('RouteProgressCalculator', () {
    test('calculates progress at the middle of a straight route', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 1)],
        latitude: 0,
        longitude: 0.5,
      );

      expect(result, isNotNull);

      expect(result!.totalRouteKm, closeTo(111.195, 0.2));

      expect(result.distanceFromStartKm, closeTo(55.598, 0.2));

      expect(result.distanceToEndKm, closeTo(55.598, 0.2));

      expect(result.distanceFromRouteMeters, closeTo(0, 1));

      expect(result.progressRatio, closeTo(0.5, 0.001));

      expect(result.progressPercent, closeTo(50, 0.1));

      expect(result.segmentIndex, 0);
    });

    test('calculates distance from an off-route point', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 1)],
        latitude: 0.01,
        longitude: 0.5,
      );

      expect(result, isNotNull);

      expect(result!.distanceFromRouteMeters, closeTo(1111.95, 10));

      expect(result.progressRatio, closeTo(0.5, 0.002));

      expect(result.isWithinCorridorMeters(2000), isTrue);

      expect(result.isWithinCorridorMeters(1000), isFalse);
    });

    test('calculates progress on a multi-segment route', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 1), point(1, 1)],
        latitude: 0.5,
        longitude: 1,
      );

      expect(result, isNotNull);

      expect(result!.totalRouteKm, closeTo(222.39, 0.5));

      expect(result.distanceFromStartKm, closeTo(166.79, 0.5));

      expect(result.distanceToEndKm, closeTo(55.60, 0.5));

      expect(result.progressRatio, closeTo(0.75, 0.01));

      expect(result.segmentIndex, 1);
    });

    test('clamps a point before the start to route start', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 1)],
        latitude: 0,
        longitude: -0.1,
      );

      expect(result, isNotNull);

      expect(result!.distanceFromStartMeters, closeTo(0, 1));

      expect(result.progressRatio, closeTo(0, 0.001));

      expect(result.distanceFromRouteMeters, greaterThan(10000));
    });

    test('clamps a point after the end to route destination', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 1)],
        latitude: 0,
        longitude: 1.1,
      );

      expect(result, isNotNull);

      expect(
        result!.distanceFromStartMeters,
        closeTo(result.totalRouteMeters, 1),
      );

      expect(result.distanceToEndMeters, closeTo(0, 1));

      expect(result.progressRatio, closeTo(1, 0.001));
    });

    test('handles duplicate route points', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 0), point(0, 1)],
        latitude: 0,
        longitude: 0.5,
      );

      expect(result, isNotNull);

      expect(result!.progressRatio, closeTo(0.5, 0.001));

      expect(result.segmentIndex, 1);
    });

    test('returns null when route has fewer than two points', () {
      expect(
        calculator.calculate(routePoints: const [], latitude: 0, longitude: 0),
        isNull,
      );

      expect(
        calculator.calculate(
          routePoints: [point(0, 0)],
          latitude: 0,
          longitude: 0,
        ),
        isNull,
      );
    });

    test('returns null when all route segments have zero length', () {
      final result = calculator.calculate(
        routePoints: [point(0, 0), point(0, 0), point(0, 0)],
        latitude: 0,
        longitude: 0,
      );

      expect(result, isNull);
    });

    test('returns null for invalid target coordinates', () {
      expect(
        calculator.calculate(
          routePoints: [point(0, 0), point(0, 1)],
          latitude: 91,
          longitude: 0,
        ),
        isNull,
      );

      expect(
        calculator.calculate(
          routePoints: [point(0, 0), point(0, 1)],
          latitude: 0,
          longitude: 181,
        ),
        isNull,
      );
    });
  });
}
