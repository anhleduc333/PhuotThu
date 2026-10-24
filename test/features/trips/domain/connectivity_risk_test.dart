import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';

void main() {
  group('ConnectivityRiskLevel', () {
    test('maps normalized scores to risk levels', () {
      expect(ConnectivityRiskLevelX.fromScore(0), ConnectivityRiskLevel.low);
      expect(ConnectivityRiskLevelX.fromScore(0.24), ConnectivityRiskLevel.low);
      expect(
        ConnectivityRiskLevelX.fromScore(0.25),
        ConnectivityRiskLevel.moderate,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(0.49),
        ConnectivityRiskLevel.moderate,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(0.50),
        ConnectivityRiskLevel.high,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(0.74),
        ConnectivityRiskLevel.high,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(0.75),
        ConnectivityRiskLevel.critical,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(1),
        ConnectivityRiskLevel.critical,
      );
    });

    test('returns unknown for invalid risk score', () {
      expect(
        ConnectivityRiskLevelX.fromScore(null),
        ConnectivityRiskLevel.unknown,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(-0.1),
        ConnectivityRiskLevel.unknown,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(1.1),
        ConnectivityRiskLevel.unknown,
      );
      expect(
        ConnectivityRiskLevelX.fromScore(double.nan),
        ConnectivityRiskLevel.unknown,
      );
    });

    test('only high and critical levels require warning', () {
      expect(ConnectivityRiskLevel.unknown.requiresWarning, isFalse);
      expect(ConnectivityRiskLevel.low.requiresWarning, isFalse);
      expect(ConnectivityRiskLevel.moderate.requiresWarning, isFalse);
      expect(ConnectivityRiskLevel.high.requiresWarning, isTrue);
      expect(ConnectivityRiskLevel.critical.requiresWarning, isTrue);
    });
  });

  group('ConnectivityRiskPoint', () {
    test('exposes distance and progress helpers', () {
      const point = ConnectivityRiskPoint(
        latitude: 21,
        longitude: 105,
        distanceFromStartMeters: 12500,
        progressRatio: 0.25,
        riskScore: 0.6,
        level: ConnectivityRiskLevel.high,
      );

      expect(point.distanceFromStartKm, 12.5);
      expect(point.progressPercent, 25);
      expect(point.requiresWarning, isTrue);
    });

    test('keeps supporting evidence', () {
      const evidence = ConnectivityRiskEvidence(
        type: ConnectivityRiskEvidenceType.terrain,
        riskScore: 0.8,
        confidence: 0.7,
        source: 'test',
        description: 'Địa hình phức tạp',
      );

      const point = ConnectivityRiskPoint(
        latitude: 21,
        longitude: 105,
        distanceFromStartMeters: 1000,
        progressRatio: 0.1,
        riskScore: 0.8,
        level: ConnectivityRiskLevel.critical,
        evidence: [evidence],
      );

      expect(point.evidence.length, 1);
      expect(point.evidence.first.type, ConnectivityRiskEvidenceType.terrain);
      expect(point.evidence.first.confidence, 0.7);
    });
  });

  group('ConnectivityRiskSegment', () {
    test('calculates segment length', () {
      const segment = ConnectivityRiskSegment(
        startDistanceMeters: 10000,
        endDistanceMeters: 35000,
        startProgressRatio: 0.1,
        endProgressRatio: 0.35,
        averageRiskScore: 0.62,
        maxRiskScore: 0.74,
        level: ConnectivityRiskLevel.high,
        sampleCount: 5,
      );

      expect(segment.lengthMeters, 25000);
      expect(segment.lengthKm, 25);
      expect(segment.startDistanceKm, 10);
      expect(segment.endDistanceKm, 35);
      expect(segment.requiresWarning, isTrue);
    });
  });

  group('ConnectivityRiskAssessment', () {
    const lowSegment = ConnectivityRiskSegment(
      startDistanceMeters: 0,
      endDistanceMeters: 50000,
      startProgressRatio: 0,
      endProgressRatio: 0.25,
      averageRiskScore: 0.15,
      maxRiskScore: 0.20,
      level: ConnectivityRiskLevel.low,
    );

    const highSegment = ConnectivityRiskSegment(
      startDistanceMeters: 50000,
      endDistanceMeters: 100000,
      startProgressRatio: 0.25,
      endProgressRatio: 0.50,
      averageRiskScore: 0.60,
      maxRiskScore: 0.70,
      level: ConnectivityRiskLevel.high,
    );

    const criticalSegment = ConnectivityRiskSegment(
      startDistanceMeters: 100000,
      endDistanceMeters: 125000,
      startProgressRatio: 0.50,
      endProgressRatio: 0.625,
      averageRiskScore: 0.85,
      maxRiskScore: 0.95,
      level: ConnectivityRiskLevel.critical,
    );

    const moderateSegment = ConnectivityRiskSegment(
      startDistanceMeters: 125000,
      endDistanceMeters: 200000,
      startProgressRatio: 0.625,
      endProgressRatio: 1,
      averageRiskScore: 0.35,
      maxRiskScore: 0.45,
      level: ConnectivityRiskLevel.moderate,
    );

    test('detects warning segments and warning distance', () {
      const assessment = ConnectivityRiskAssessment(
        totalRouteMeters: 200000,
        overallRiskScore: 0.55,
        overallLevel: ConnectivityRiskLevel.high,
        segments: [lowSegment, highSegment, criticalSegment, moderateSegment],
      );

      expect(assessment.hasRiskData, isTrue);
      expect(assessment.hasWarningSegments, isTrue);
      expect(assessment.warningSegments.length, 2);
      expect(assessment.warningDistanceMeters, 75000);
      expect(assessment.warningDistanceKm, 75);
      expect(assessment.warningRouteRatio, closeTo(0.375, 0.0001));
      expect(assessment.warningRoutePercent, closeTo(37.5, 0.001));
    });

    test('finds highest risk segment', () {
      const assessment = ConnectivityRiskAssessment(
        totalRouteMeters: 200000,
        overallRiskScore: 0.55,
        overallLevel: ConnectivityRiskLevel.high,
        segments: [lowSegment, highSegment, criticalSegment, moderateSegment],
      );

      expect(assessment.highestRiskSegment, same(criticalSegment));
    });

    test('uses max risk score as tie breaker', () {
      const first = ConnectivityRiskSegment(
        startDistanceMeters: 0,
        endDistanceMeters: 10000,
        startProgressRatio: 0,
        endProgressRatio: 0.1,
        averageRiskScore: 0.6,
        maxRiskScore: 0.65,
        level: ConnectivityRiskLevel.high,
      );

      const second = ConnectivityRiskSegment(
        startDistanceMeters: 10000,
        endDistanceMeters: 20000,
        startProgressRatio: 0.1,
        endProgressRatio: 0.2,
        averageRiskScore: 0.62,
        maxRiskScore: 0.72,
        level: ConnectivityRiskLevel.high,
      );

      const assessment = ConnectivityRiskAssessment(
        totalRouteMeters: 20000,
        overallRiskScore: 0.6,
        overallLevel: ConnectivityRiskLevel.high,
        segments: [first, second],
      );

      expect(assessment.highestRiskSegment, same(second));
    });

    test('handles empty assessment safely', () {
      const assessment = ConnectivityRiskAssessment(
        totalRouteMeters: 0,
        overallRiskScore: 0,
        overallLevel: ConnectivityRiskLevel.unknown,
        segments: [],
      );

      expect(assessment.hasRiskData, isFalse);
      expect(assessment.hasWarningSegments, isFalse);
      expect(assessment.warningDistanceMeters, 0);
      expect(assessment.warningRouteRatio, 0);
      expect(assessment.warningRoutePercent, 0);
      expect(assessment.highestRiskSegment, isNull);
    });
  });
}
