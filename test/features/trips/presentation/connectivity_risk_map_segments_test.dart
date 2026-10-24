import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/presentation/connectivity_risk_map_segments.dart';

void main() {
  const builder = ConnectivityRiskMapSegmentBuilder();

  RoutePoint point(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  ConnectivityRiskSegment segment({
    required double startKm,
    required double endKm,
    required ConnectivityRiskLevel level,
    required double average,
    double? max,
    double totalKm = 111.2,
  }) {
    return ConnectivityRiskSegment(
      startDistanceMeters: startKm * 1000,
      endDistanceMeters: endKm * 1000,
      startProgressRatio: startKm / totalKm,
      endProgressRatio: endKm / totalKm,
      averageRiskScore: average,
      maxRiskScore: max ?? average,
      level: level,
    );
  }

  ConnectivityRiskAssessment assessment({
    required List<ConnectivityRiskSegment> segments,
    double totalMeters = 111200,
  }) {
    return ConnectivityRiskAssessment(
      totalRouteMeters: totalMeters,
      overallRiskScore: 0.5,
      overallLevel: ConnectivityRiskLevel.high,
      segments: segments,
    );
  }

  group('ConnectivityRiskMapSegmentBuilder', () {
    test('cuts a simple route at risk boundaries', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 1)],
        assessment: assessment(
          segments: [
            segment(
              startKm: 0,
              endKm: 55.6,
              level: ConnectivityRiskLevel.low,
              average: 0.2,
            ),
            segment(
              startKm: 55.6,
              endKm: 111.2,
              level: ConnectivityRiskLevel.high,
              average: 0.6,
            ),
          ],
        ),
      );

      expect(result.length, 2);
      expect(result.first.level, ConnectivityRiskLevel.low);
      expect(result.last.level, ConnectivityRiskLevel.high);

      expect(result.first.points.last.longitude, closeTo(0.5, 0.02));

      expect(result.last.points.first.longitude, closeTo(0.5, 0.02));
    });

    test('keeps intermediate route vertices inside segment', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 0.5), point(0.5, 0.5)],
        assessment: ConnectivityRiskAssessment(
          totalRouteMeters: 111200,
          overallRiskScore: 0.6,
          overallLevel: ConnectivityRiskLevel.high,
          segments: [
            ConnectivityRiskSegment(
              startDistanceMeters: 20000,
              endDistanceMeters: 90000,
              startProgressRatio: 0.18,
              endProgressRatio: 0.81,
              averageRiskScore: 0.6,
              maxRiskScore: 0.7,
              level: ConnectivityRiskLevel.high,
            ),
          ],
        ),
      );

      expect(result.length, 1);

      expect(
        result.single.points.any(
          (item) =>
              (item.latitude - 0).abs() < 0.000001 &&
              (item.longitude - 0.5).abs() < 0.000001,
        ),
        isTrue,
      );
    });

    test('preserves risk metadata', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 1)],
        assessment: assessment(
          segments: [
            segment(
              startKm: 0,
              endKm: 111.2,
              level: ConnectivityRiskLevel.critical,
              average: 0.82,
              max: 0.95,
            ),
          ],
        ),
      );

      expect(result.single.level, ConnectivityRiskLevel.critical);
      expect(result.single.averageRiskScore, 0.82);
      expect(result.single.maxRiskScore, 0.95);
      expect(result.single.lengthKm, closeTo(111.2, 0.1));
    });

    test('clamps assessment segment to actual route length', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 1)],
        assessment: ConnectivityRiskAssessment(
          totalRouteMeters: 200000,
          overallRiskScore: 0.6,
          overallLevel: ConnectivityRiskLevel.high,
          segments: [
            const ConnectivityRiskSegment(
              startDistanceMeters: 0,
              endDistanceMeters: 200000,
              startProgressRatio: 0,
              endProgressRatio: 1,
              averageRiskScore: 0.6,
              maxRiskScore: 0.7,
              level: ConnectivityRiskLevel.high,
            ),
          ],
        ),
      );

      expect(result.length, 1);
      expect(result.single.points.first.longitude, closeTo(0, 0.0001));
      expect(result.single.points.last.longitude, closeTo(1, 0.0001));
      expect(result.single.endDistanceMeters, lessThan(120000));
    });

    test('skips zero-length risk segments', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 1)],
        assessment: ConnectivityRiskAssessment(
          totalRouteMeters: 111200,
          overallRiskScore: 0.2,
          overallLevel: ConnectivityRiskLevel.low,
          segments: [
            const ConnectivityRiskSegment(
              startDistanceMeters: 50000,
              endDistanceMeters: 50000,
              startProgressRatio: 0.45,
              endProgressRatio: 0.45,
              averageRiskScore: 0.2,
              maxRiskScore: 0.2,
              level: ConnectivityRiskLevel.low,
            ),
          ],
        ),
      );

      expect(result, isEmpty);
    });

    test('returns empty for invalid route', () {
      final value = assessment(
        segments: [
          segment(
            startKm: 0,
            endKm: 10,
            level: ConnectivityRiskLevel.low,
            average: 0.1,
          ),
        ],
      );

      expect(builder.build(routePoints: const [], assessment: value), isEmpty);

      expect(
        builder.build(routePoints: [point(0, 0)], assessment: value),
        isEmpty,
      );
    });

    test('returns empty for zero-length route geometry', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 0)],
        assessment: assessment(
          segments: [
            segment(
              startKm: 0,
              endKm: 10,
              level: ConnectivityRiskLevel.low,
              average: 0.1,
            ),
          ],
        ),
      );

      expect(result, isEmpty);
    });

    test('returns immutable point collections', () {
      final result = builder.build(
        routePoints: [point(0, 0), point(0, 1)],
        assessment: assessment(
          segments: [
            segment(
              startKm: 0,
              endKm: 111.2,
              level: ConnectivityRiskLevel.low,
              average: 0.1,
            ),
          ],
        ),
      );

      expect(
        () => result.single.points.add(point(0, 2)),
        throwsUnsupportedError,
      );
    });
  });
}
