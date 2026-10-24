import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_scorer.dart';

void main() {
  const scorer = ConnectivityRiskScorer();

  ConnectivityRiskEvidence evidence({
    required ConnectivityRiskEvidenceType type,
    required double risk,
    double confidence = 1,
    String source = 'test',
  }) {
    return ConnectivityRiskEvidence(
      type: type,
      riskScore: risk,
      confidence: confidence,
      source: source,
    );
  }

  group('ConnectivityRiskScorer.scoreEvidence', () {
    test('uses weighted evidence to calculate normalized risk score', () {
      final result = scorer.scoreEvidence(
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 0.8,
          ),
          evidence(type: ConnectivityRiskEvidenceType.terrain, risk: 0.4),
        ],
      );

      expect(result, isNotNull);

      // (0.8 * 0.50 + 0.4 * 0.20) / (0.50 + 0.20)
      expect(result!.riskScore, closeTo(0.685714, 0.0001));

      expect(result.level, ConnectivityRiskLevel.high);

      expect(result.requiresWarning, isTrue);
    });

    test('reduces effective influence using evidence confidence', () {
      final result = scorer.scoreEvidence(
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 1,
            confidence: 0.5,
          ),
          evidence(
            type: ConnectivityRiskEvidenceType.terrain,
            risk: 0,
            confidence: 1,
          ),
        ],
      );

      expect(result, isNotNull);

      // mobile effective weight = 0.50 * 0.5 = 0.25
      // terrain effective weight = 0.20
      // score = 0.25 / 0.45
      expect(result!.riskScore, closeTo(0.555556, 0.0001));
    });

    test('ignores evidence below minimum confidence', () {
      final result = scorer.scoreEvidence(
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 1,
            confidence: 0.1,
          ),
          evidence(
            type: ConnectivityRiskEvidenceType.terrain,
            risk: 0.2,
            confidence: 1,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.contributions.length, 1);
      expect(
        result.contributions.single.evidence.type,
        ConnectivityRiskEvidenceType.terrain,
      );
      expect(result.riskScore, closeTo(0.2, 0.0001));
    });

    test('returns null when all evidence confidence is too low', () {
      final result = scorer.scoreEvidence(
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 0.8,
            confidence: 0.1,
          ),
          evidence(
            type: ConnectivityRiskEvidenceType.terrain,
            risk: 0.8,
            confidence: 0.19,
          ),
        ],
      );

      expect(result, isNull);
    });

    test('supports custom scoring weights', () {
      const policy = ConnectivityRiskScoringPolicy(
        mobileCoverageWeight: 0,
        terrainWeight: 1,
        settlementDensityWeight: 0,
        roadIsolationWeight: 0,
        manualWeight: 0,
      );

      final result = scorer.scoreEvidence(
        policy: policy,
        evidence: [
          evidence(type: ConnectivityRiskEvidenceType.mobileCoverage, risk: 1),
          evidence(type: ConnectivityRiskEvidenceType.terrain, risk: 0.3),
        ],
      );

      expect(result, isNotNull);
      expect(result!.riskScore, closeTo(0.3, 0.0001));
      expect(result.contributions.length, 1);
    });

    test('returns null for invalid scoring policy', () {
      const policy = ConnectivityRiskScoringPolicy(
        mobileCoverageWeight: 0,
        terrainWeight: 0,
        settlementDensityWeight: 0,
        roadIsolationWeight: 0,
        manualWeight: 0,
      );

      final result = scorer.scoreEvidence(
        policy: policy,
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 0.8,
          ),
        ],
      );

      expect(result, isNull);
    });

    test('returns null when effective weight is below required minimum', () {
      const policy = ConnectivityRiskScoringPolicy(
        mobileCoverageWeight: 0.01,
        terrainWeight: 0,
        settlementDensityWeight: 0,
        roadIsolationWeight: 0,
        manualWeight: 0,
        minimumEvidenceConfidence: 0,
        minimumEffectiveWeight: 0.05,
      );

      final result = scorer.scoreEvidence(
        policy: policy,
        evidence: [
          evidence(type: ConnectivityRiskEvidenceType.mobileCoverage, risk: 1),
        ],
      );

      expect(result, isNull);
    });
  });

  group('ConnectivityRiskScorer.scorePoint', () {
    test('builds connectivity risk point from scored evidence', () {
      final point = scorer.scorePoint(
        latitude: 21.1,
        longitude: 105.8,
        distanceFromStartMeters: 25000,
        progressRatio: 0.25,
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 0.9,
          ),
          evidence(type: ConnectivityRiskEvidenceType.roadIsolation, risk: 0.8),
        ],
      );

      expect(point, isNotNull);
      expect(point!.latitude, 21.1);
      expect(point.longitude, 105.8);
      expect(point.distanceFromStartKm, 25);
      expect(point.progressPercent, 25);
      expect(point.evidence.length, 2);
      expect(point.level.requiresWarning, isTrue);
    });

    test('stores only evidence actually used by scorer', () {
      final point = scorer.scorePoint(
        latitude: 21,
        longitude: 105,
        distanceFromStartMeters: 1000,
        progressRatio: 0.1,
        evidence: [
          evidence(
            type: ConnectivityRiskEvidenceType.mobileCoverage,
            risk: 0.9,
            confidence: 0.1,
          ),
          evidence(
            type: ConnectivityRiskEvidenceType.terrain,
            risk: 0.4,
            confidence: 1,
          ),
        ],
      );

      expect(point, isNotNull);
      expect(point!.evidence.length, 1);
      expect(point.evidence.single.type, ConnectivityRiskEvidenceType.terrain);
    });

    test('returns null for invalid coordinates or route progress', () {
      final validEvidence = [
        evidence(type: ConnectivityRiskEvidenceType.mobileCoverage, risk: 0.5),
      ];

      expect(
        scorer.scorePoint(
          latitude: 91,
          longitude: 105,
          distanceFromStartMeters: 1000,
          progressRatio: 0.1,
          evidence: validEvidence,
        ),
        isNull,
      );

      expect(
        scorer.scorePoint(
          latitude: 21,
          longitude: 181,
          distanceFromStartMeters: 1000,
          progressRatio: 0.1,
          evidence: validEvidence,
        ),
        isNull,
      );

      expect(
        scorer.scorePoint(
          latitude: 21,
          longitude: 105,
          distanceFromStartMeters: -1,
          progressRatio: 0.1,
          evidence: validEvidence,
        ),
        isNull,
      );

      expect(
        scorer.scorePoint(
          latitude: 21,
          longitude: 105,
          distanceFromStartMeters: 1000,
          progressRatio: 1.1,
          evidence: validEvidence,
        ),
        isNull,
      );
    });
  });
}
