import 'connectivity_risk.dart';

class ConnectivityRiskScoringPolicy {
  const ConnectivityRiskScoringPolicy({
    this.mobileCoverageWeight = 0.50,
    this.terrainWeight = 0.20,
    this.settlementDensityWeight = 0.12,
    this.roadIsolationWeight = 0.13,
    this.manualWeight = 0.05,
    this.minimumEvidenceConfidence = 0.20,
    this.minimumEffectiveWeight = 0.05,
  });

  /// Trọng số của dữ liệu phủ sóng.
  final double mobileCoverageWeight;

  /// Trọng số của yếu tố địa hình.
  final double terrainWeight;

  /// Trọng số của mật độ khu dân cư.
  final double settlementDensityWeight;

  /// Trọng số mức độ biệt lập của tuyến.
  final double roadIsolationWeight;

  /// Trọng số đánh giá thủ công.
  final double manualWeight;

  /// Evidence có confidence thấp hơn ngưỡng này
  /// sẽ không được dùng để tính điểm.
  final double minimumEvidenceConfidence;

  /// Tổng trọng số hiệu dụng tối thiểu để một điểm
  /// được coi là có đủ dữ liệu đánh giá.
  final double minimumEffectiveWeight;

  bool get isValid {
    return mobileCoverageWeight >= 0 &&
        terrainWeight >= 0 &&
        settlementDensityWeight >= 0 &&
        roadIsolationWeight >= 0 &&
        manualWeight >= 0 &&
        minimumEvidenceConfidence >= 0 &&
        minimumEvidenceConfidence <= 1 &&
        minimumEffectiveWeight > 0 &&
        totalBaseWeight > 0;
  }

  double get totalBaseWeight =>
      mobileCoverageWeight +
      terrainWeight +
      settlementDensityWeight +
      roadIsolationWeight +
      manualWeight;

  double weightFor(ConnectivityRiskEvidenceType type) {
    switch (type) {
      case ConnectivityRiskEvidenceType.mobileCoverage:
        return mobileCoverageWeight;
      case ConnectivityRiskEvidenceType.terrain:
        return terrainWeight;
      case ConnectivityRiskEvidenceType.settlementDensity:
        return settlementDensityWeight;
      case ConnectivityRiskEvidenceType.roadIsolation:
        return roadIsolationWeight;
      case ConnectivityRiskEvidenceType.manual:
        return manualWeight;
    }
  }
}

class ConnectivityRiskScoreContribution {
  const ConnectivityRiskScoreContribution({
    required this.evidence,
    required this.baseWeight,
    required this.effectiveWeight,
    required this.weightedRisk,
  });

  final ConnectivityRiskEvidence evidence;

  /// Trọng số cấu hình cho loại evidence.
  final double baseWeight;

  /// baseWeight × confidence.
  final double effectiveWeight;

  /// riskScore × effectiveWeight.
  final double weightedRisk;
}

class ConnectivityRiskScoreResult {
  const ConnectivityRiskScoreResult({
    required this.riskScore,
    required this.level,
    required this.totalEffectiveWeight,
    required this.contributions,
  });

  final double riskScore;
  final ConnectivityRiskLevel level;

  /// Tổng trọng số sau khi đã nhân confidence.
  final double totalEffectiveWeight;

  final List<ConnectivityRiskScoreContribution> contributions;

  bool get requiresWarning => level.requiresWarning;
}

class ConnectivityRiskScorer {
  const ConnectivityRiskScorer();

  ConnectivityRiskScoreResult? scoreEvidence({
    required List<ConnectivityRiskEvidence> evidence,
    ConnectivityRiskScoringPolicy policy =
        const ConnectivityRiskScoringPolicy(),
  }) {
    if (!policy.isValid || evidence.isEmpty) {
      return null;
    }

    final contributions = <ConnectivityRiskScoreContribution>[];

    var weightedRiskSum = 0.0;
    var totalEffectiveWeight = 0.0;

    for (final item in evidence) {
      if (item.confidence < policy.minimumEvidenceConfidence) {
        continue;
      }

      final baseWeight = policy.weightFor(item.type);

      if (baseWeight <= 0) {
        continue;
      }

      final effectiveWeight = baseWeight * item.confidence;

      if (effectiveWeight <= 0) {
        continue;
      }

      final weightedRisk = item.riskScore * effectiveWeight;

      contributions.add(
        ConnectivityRiskScoreContribution(
          evidence: item,
          baseWeight: baseWeight,
          effectiveWeight: effectiveWeight,
          weightedRisk: weightedRisk,
        ),
      );

      weightedRiskSum += weightedRisk;
      totalEffectiveWeight += effectiveWeight;
    }

    if (contributions.isEmpty ||
        totalEffectiveWeight < policy.minimumEffectiveWeight) {
      return null;
    }

    final riskScore = (weightedRiskSum / totalEffectiveWeight).clamp(0.0, 1.0);

    return ConnectivityRiskScoreResult(
      riskScore: riskScore,
      level: ConnectivityRiskLevelX.fromScore(riskScore),
      totalEffectiveWeight: totalEffectiveWeight,
      contributions: List<ConnectivityRiskScoreContribution>.unmodifiable(
        contributions,
      ),
    );
  }

  ConnectivityRiskPoint? scorePoint({
    required double latitude,
    required double longitude,
    required double distanceFromStartMeters,
    required double progressRatio,
    required List<ConnectivityRiskEvidence> evidence,
    ConnectivityRiskScoringPolicy policy =
        const ConnectivityRiskScoringPolicy(),
  }) {
    if (!_isValidCoordinate(latitude, longitude) ||
        distanceFromStartMeters < 0 ||
        progressRatio < 0 ||
        progressRatio > 1) {
      return null;
    }

    final result = scoreEvidence(evidence: evidence, policy: policy);

    if (result == null) {
      return null;
    }

    return ConnectivityRiskPoint(
      latitude: latitude,
      longitude: longitude,
      distanceFromStartMeters: distanceFromStartMeters,
      progressRatio: progressRatio,
      riskScore: result.riskScore,
      level: result.level,
      evidence: List<ConnectivityRiskEvidence>.unmodifiable(
        result.contributions.map((item) => item.evidence),
      ),
    );
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
