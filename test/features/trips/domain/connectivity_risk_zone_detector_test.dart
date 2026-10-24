import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_zone_detector.dart';

void main() {
  const detector = ConnectivityRiskZoneDetector();

  ConnectivityRiskPoint point({
    required double km,
    required double score,
    double totalKm = 100,
  }) {
    return ConnectivityRiskPoint(
      latitude: 21 + km / 10000,
      longitude: 105,
      distanceFromStartMeters: km * 1000,
      progressRatio: km / totalKm,
      riskScore: score,
      level: ConnectivityRiskLevelX.fromScore(score),
    );
  }

  group('ConnectivityRiskZoneDetector', () {
    test('groups consecutive points with same risk level', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          point(km: 0, score: 0.1),
          point(km: 20, score: 0.2),
          point(km: 40, score: 0.6),
          point(km: 60, score: 0.7),
          point(km: 80, score: 0.3),
          point(km: 100, score: 0.4),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.segments.length, 3);

      expect(assessment.segments[0].level, ConnectivityRiskLevel.low);

      expect(assessment.segments[1].level, ConnectivityRiskLevel.high);

      expect(assessment.segments[2].level, ConnectivityRiskLevel.moderate);
    });

    test('uses midpoints as boundaries between risk zones', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          point(km: 0, score: 0.1),
          point(km: 20, score: 0.1),
          point(km: 40, score: 0.6),
          point(km: 60, score: 0.6),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.segments.length, 2);

      expect(assessment.segments.first.endDistanceKm, closeTo(30, 0.001));

      expect(assessment.segments[1].startDistanceKm, closeTo(30, 0.001));

      expect(assessment.segments.last.endDistanceKm, 100);
    });

    test('sorts points before zone detection', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          point(km: 80, score: 0.8),
          point(km: 0, score: 0.1),
          point(km: 40, score: 0.6),
          point(km: 20, score: 0.1),
        ],
      );

      expect(assessment, isNotNull);

      expect(
        assessment!.sampledPoints
            .map((item) => item.distanceFromStartKm)
            .toList(),
        [0, 20, 40, 80],
      );
    });

    test('deduplicates points at same route distance using higher risk', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          point(km: 0, score: 0.1),
          point(km: 40, score: 0.3),
          point(km: 40, score: 0.8),
          point(km: 100, score: 0.1),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.sampledPoints.length, 3);

      final fortyKmPoint = assessment.sampledPoints.singleWhere(
        (item) => item.distanceFromStartKm == 40,
      );

      expect(fortyKmPoint.riskScore, 0.8);
    });

    test('calculates overall score weighted by segment length', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          point(km: 0, score: 0.1),
          point(km: 20, score: 0.1),
          point(km: 40, score: 0.6),
          point(km: 60, score: 0.6),
          point(km: 80, score: 0.6),
          point(km: 100, score: 0.6),
        ],
      );

      expect(assessment, isNotNull);

      // Low zone ~0..30 km, high zone ~30..100 km.
      // 0.1*30% + 0.6*70% = 0.45
      expect(assessment!.overallRiskScore, closeTo(0.45, 0.001));

      expect(assessment.overallLevel, ConnectivityRiskLevel.moderate);
    });

    test('reports warning distance through generated assessment', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          point(km: 0, score: 0.1),
          point(km: 20, score: 0.1),
          point(km: 40, score: 0.6),
          point(km: 60, score: 0.6),
          point(km: 80, score: 0.8),
          point(km: 100, score: 0.8),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.hasWarningSegments, isTrue);

      expect(assessment.warningDistanceKm, greaterThan(0));

      expect(assessment.highestRiskSegment, isNotNull);

      expect(
        assessment.highestRiskSegment!.level,
        ConnectivityRiskLevel.critical,
      );
    });

    test('merges a very short transition zone into neighbor', () {
      const policy = ConnectivityRiskZonePolicy(
        minimumSegmentLengthMeters: 15000,
      );

      final assessment = detector.detect(
        totalRouteMeters: 100000,
        policy: policy,
        points: [
          point(km: 0, score: 0.1),
          point(km: 20, score: 0.1),
          point(km: 40, score: 0.6),
          point(km: 42, score: 0.3),
          point(km: 44, score: 0.6),
          point(km: 70, score: 0.6),
          point(km: 100, score: 0.6),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.segments.length, lessThan(4));
    });

    test('supports one sampled point by covering whole route', () {
      final assessment = detector.detect(
        totalRouteMeters: 80000,
        points: [
          ConnectivityRiskPoint(
            latitude: 21,
            longitude: 105,
            distanceFromStartMeters: 40000,
            progressRatio: 0.5,
            riskScore: 0.8,
            level: ConnectivityRiskLevel.critical,
          ),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.segments.length, 1);

      expect(assessment.segments.single.lengthKm, 80);

      expect(assessment.overallRiskScore, 0.8);
    });

    test('ignores points outside route bounds', () {
      final assessment = detector.detect(
        totalRouteMeters: 100000,
        points: [
          ConnectivityRiskPoint(
            latitude: 21,
            longitude: 105,
            distanceFromStartMeters: 120000,
            progressRatio: 1,
            riskScore: 0.9,
            level: ConnectivityRiskLevel.critical,
          ),
          point(km: 50, score: 0.2),
        ],
      );

      expect(assessment, isNotNull);

      expect(assessment!.sampledPoints.length, 1);

      expect(assessment.sampledPoints.single.distanceFromStartKm, 50);
    });

    test('returns null for invalid inputs', () {
      expect(
        detector.detect(
          totalRouteMeters: 0,
          points: [point(km: 0, score: 0.1)],
        ),
        isNull,
      );

      expect(
        detector.detect(totalRouteMeters: 100000, points: const []),
        isNull,
      );

      expect(
        detector.detect(
          totalRouteMeters: 100000,
          points: [point(km: 50, score: 0.1)],
          policy: const ConnectivityRiskZonePolicy(
            minimumSegmentLengthMeters: -1,
          ),
        ),
        isNull,
      );
    });
  });
}
