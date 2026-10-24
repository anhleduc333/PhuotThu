import 'offline_readiness.dart';

class OfflineReadinessScoringPolicy {
  const OfflineReadinessScoringPolicy({
    this.tripDetailsWeight = 0.15,
    this.routeGeometryWeight = 0.25,
    this.routeSummaryWeight = 0.10,
    this.essentialPoisWeight = 0.15,
    this.emergencyInfoWeight = 0.10,
    this.connectivityRiskAnalysisWeight = 0.10,
    this.offlineMapWeight = 0.15,
    this.staleFactor = 0.50,
    this.requiredUnsupportedFactor = 0.50,
    this.readyThreshold = 0.85,
    this.needsAttentionThreshold = 0.55,
    this.connectivityRiskTriggerPercent = 10,
    this.highConnectivityRiskTriggerPercent = 30,
  });

  final double tripDetailsWeight;
  final double routeGeometryWeight;
  final double routeSummaryWeight;
  final double essentialPoisWeight;
  final double emergencyInfoWeight;
  final double connectivityRiskAnalysisWeight;
  final double offlineMapWeight;

  /// Hạng mục stale vẫn có giá trị một phần.
  final double staleFactor;

  /// Capability chưa hỗ trợ nhưng đã bị policy nâng thành required
  /// vẫn được ghi nhận một phần thay vì coi là lỗi của người dùng.
  ///
  /// Tuy nhiên trạng thái này luôn chặn READY.
  final double requiredUnsupportedFactor;

  /// Score tối thiểu để được coi là ready.
  final double readyThreshold;

  /// Score dưới ngưỡng này được coi là notReady
  /// nếu không rơi vào trường hợp thiếu required item trước đó.
  final double needsAttentionThreshold;

  /// Khi tỷ lệ HIGH/CRITICAL trên route đạt ngưỡng này,
  /// offline map và connectivity-risk analysis được nâng thành required.
  final double connectivityRiskTriggerPercent;

  /// Khi tỷ lệ HIGH/CRITICAL đạt ngưỡng cao này,
  /// essential POIs và emergency info cũng được nâng thành required.
  final double highConnectivityRiskTriggerPercent;

  bool get isValid {
    return tripDetailsWeight >= 0 &&
        routeGeometryWeight >= 0 &&
        routeSummaryWeight >= 0 &&
        essentialPoisWeight >= 0 &&
        emergencyInfoWeight >= 0 &&
        connectivityRiskAnalysisWeight >= 0 &&
        offlineMapWeight >= 0 &&
        totalWeight > 0 &&
        staleFactor >= 0 &&
        staleFactor <= 1 &&
        requiredUnsupportedFactor >= 0 &&
        requiredUnsupportedFactor < 1 &&
        needsAttentionThreshold >= 0 &&
        needsAttentionThreshold <= 1 &&
        readyThreshold >= 0 &&
        readyThreshold <= 1 &&
        needsAttentionThreshold <= readyThreshold &&
        connectivityRiskTriggerPercent >= 0 &&
        connectivityRiskTriggerPercent <= 100 &&
        highConnectivityRiskTriggerPercent >= connectivityRiskTriggerPercent &&
        highConnectivityRiskTriggerPercent <= 100;
  }

  double get totalWeight =>
      tripDetailsWeight +
      routeGeometryWeight +
      routeSummaryWeight +
      essentialPoisWeight +
      emergencyInfoWeight +
      connectivityRiskAnalysisWeight +
      offlineMapWeight;

  double weightFor(OfflineReadinessItemType type) {
    switch (type) {
      case OfflineReadinessItemType.tripDetails:
        return tripDetailsWeight;
      case OfflineReadinessItemType.routeGeometry:
        return routeGeometryWeight;
      case OfflineReadinessItemType.routeSummary:
        return routeSummaryWeight;
      case OfflineReadinessItemType.essentialPois:
        return essentialPoisWeight;
      case OfflineReadinessItemType.emergencyInfo:
        return emergencyInfoWeight;
      case OfflineReadinessItemType.connectivityRiskAnalysis:
        return connectivityRiskAnalysisWeight;
      case OfflineReadinessItemType.offlineMap:
        return offlineMapWeight;
    }
  }
}

class OfflineReadinessScoreBreakdown {
  const OfflineReadinessScoreBreakdown({
    required this.item,
    required this.weight,
    required this.statusFactor,
    required this.weightedScore,
  });

  final OfflineReadinessItem item;
  final double weight;
  final double statusFactor;
  final double weightedScore;
}

class OfflineReadinessScoringResult {
  const OfflineReadinessScoringResult({
    required this.assessment,
    required this.breakdown,
    required this.connectivityEscalatedTypes,
  });

  final OfflineReadinessAssessment assessment;
  final List<OfflineReadinessScoreBreakdown> breakdown;

  /// Những item type được nâng thành required do Connectivity Risk.
  final Set<OfflineReadinessItemType> connectivityEscalatedTypes;

  bool get hasConnectivityEscalation => connectivityEscalatedTypes.isNotEmpty;
}

class OfflineReadinessScorer {
  const OfflineReadinessScorer();

  OfflineReadinessScoringResult? score({
    required List<OfflineReadinessItem> items,
    double? connectivityWarningRoutePercent,
    DateTime? assessedAt,
    bool recommendedBeforeDeparture = true,
    OfflineReadinessScoringPolicy policy =
        const OfflineReadinessScoringPolicy(),
  }) {
    if (!policy.isValid || items.isEmpty) {
      return null;
    }

    if (connectivityWarningRoutePercent != null &&
        (connectivityWarningRoutePercent < 0 ||
            connectivityWarningRoutePercent > 100 ||
            !connectivityWarningRoutePercent.isFinite)) {
      return null;
    }

    final escalatedTypes = _connectivityEscalatedTypes(
      connectivityWarningRoutePercent,
      policy,
    );

    final normalizedItems = items
        .map(
          (item) => _withRequiredness(
            item,
            item.isRequired || escalatedTypes.contains(item.type),
          ),
        )
        .toList(growable: false);

    final breakdown = <OfflineReadinessScoreBreakdown>[];

    var weightedScoreSum = 0.0;
    var effectiveWeightSum = 0.0;

    for (final item in normalizedItems) {
      final weight = policy.weightFor(item.type);

      if (weight <= 0) {
        continue;
      }

      // Optional unsupported capabilities are outside the scope of the
      // current app version, so they do not affect the score.
      //
      // If policy escalates an unsupported capability to required,
      // it must participate in scoring and must prevent a false READY.
      if (item.status == OfflineReadinessItemStatus.notApplicable &&
          !item.isRequired) {
        continue;
      }

      final factor = _statusFactor(item, policy);

      final weightedScore = weight * factor;

      breakdown.add(
        OfflineReadinessScoreBreakdown(
          item: item,
          weight: weight,
          statusFactor: factor,
          weightedScore: weightedScore,
        ),
      );

      weightedScoreSum += weightedScore;
      effectiveWeightSum += weight;
    }

    if (effectiveWeightSum <= 0) {
      return null;
    }

    final score = (weightedScoreSum / effectiveWeightSum).clamp(0.0, 1.0);

    final level = _resolveLevel(
      score: score,
      items: normalizedItems,
      policy: policy,
    );

    final assessment = OfflineReadinessAssessment(
      level: level,
      score: score,
      items: List<OfflineReadinessItem>.unmodifiable(normalizedItems),
      assessedAt: assessedAt,
      connectivityWarningRoutePercent: connectivityWarningRoutePercent,
      recommendedBeforeDeparture: recommendedBeforeDeparture,
    );

    return OfflineReadinessScoringResult(
      assessment: assessment,
      breakdown: List<OfflineReadinessScoreBreakdown>.unmodifiable(breakdown),
      connectivityEscalatedTypes: Set<OfflineReadinessItemType>.unmodifiable(
        escalatedTypes,
      ),
    );
  }

  Set<OfflineReadinessItemType> _connectivityEscalatedTypes(
    double? warningPercent,
    OfflineReadinessScoringPolicy policy,
  ) {
    if (warningPercent == null ||
        warningPercent < policy.connectivityRiskTriggerPercent) {
      return const {};
    }

    final types = <OfflineReadinessItemType>{
      OfflineReadinessItemType.offlineMap,
      OfflineReadinessItemType.connectivityRiskAnalysis,
    };

    if (warningPercent >= policy.highConnectivityRiskTriggerPercent) {
      types.addAll({
        OfflineReadinessItemType.essentialPois,
        OfflineReadinessItemType.emergencyInfo,
      });
    }

    return types;
  }

  OfflineReadinessItem _withRequiredness(
    OfflineReadinessItem item,
    bool isRequired,
  ) {
    if (item.isRequired == isRequired) {
      return item;
    }

    return OfflineReadinessItem(
      type: item.type,
      status: item.status,
      isRequired: isRequired,
      title: item.title,
      description: item.description,
      lastUpdatedAt: item.lastUpdatedAt,
      estimatedSizeBytes: item.estimatedSizeBytes,
    );
  }

  double _statusFactor(
    OfflineReadinessItem item,
    OfflineReadinessScoringPolicy policy,
  ) {
    switch (item.status) {
      case OfflineReadinessItemStatus.missing:
        return 0;
      case OfflineReadinessItemStatus.stale:
        return policy.staleFactor;
      case OfflineReadinessItemStatus.ready:
        return 1;
      case OfflineReadinessItemStatus.notApplicable:
        return item.isRequired ? policy.requiredUnsupportedFactor : 1;
    }
  }

  OfflineReadinessLevel _resolveLevel({
    required double score,
    required List<OfflineReadinessItem> items,
    required OfflineReadinessScoringPolicy policy,
  }) {
    final hasMissingRequired = items.any(
      (item) =>
          item.isRequired && item.status == OfflineReadinessItemStatus.missing,
    );

    if (hasMissingRequired) {
      return OfflineReadinessLevel.notReady;
    }

    final hasRequiredUnsupported = items.any(
      (item) =>
          item.isRequired &&
          item.status == OfflineReadinessItemStatus.notApplicable,
    );

    final hasStaleRequired = items.any(
      (item) =>
          item.isRequired && item.status == OfflineReadinessItemStatus.stale,
    );

    if (!hasRequiredUnsupported &&
        !hasStaleRequired &&
        score >= policy.readyThreshold) {
      return OfflineReadinessLevel.ready;
    }

    if (score < policy.needsAttentionThreshold) {
      return OfflineReadinessLevel.notReady;
    }

    return OfflineReadinessLevel.needsAttention;
  }
}
