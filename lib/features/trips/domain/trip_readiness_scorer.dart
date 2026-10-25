import 'trip_readiness.dart';

class TripReadinessScoringPolicy {
  const TripReadinessScoringPolicy({
    this.offlineWeight = 0.20,
    this.vehicleWeight = 0.25,
    this.personalWeight = 0.15,
    this.routeWeight = 0.25,
    this.emergencyWeight = 0.15,
    this.needsAttentionFactor = 0.50,
    this.readyThreshold = 0.85,
    this.needsAttentionThreshold = 0.55,
  });

  final double offlineWeight;
  final double vehicleWeight;
  final double personalWeight;
  final double routeWeight;
  final double emergencyWeight;

  final double needsAttentionFactor;

  final double readyThreshold;
  final double needsAttentionThreshold;

  double weightFor(TripReadinessCategory category) {
    switch (category) {
      case TripReadinessCategory.offline:
        return offlineWeight;
      case TripReadinessCategory.vehicle:
        return vehicleWeight;
      case TripReadinessCategory.personal:
        return personalWeight;
      case TripReadinessCategory.route:
        return routeWeight;
      case TripReadinessCategory.emergency:
        return emergencyWeight;
    }
  }

  double get totalWeight =>
      offlineWeight +
      vehicleWeight +
      personalWeight +
      routeWeight +
      emergencyWeight;

  bool get isValid =>
      offlineWeight >= 0 &&
      vehicleWeight >= 0 &&
      personalWeight >= 0 &&
      routeWeight >= 0 &&
      emergencyWeight >= 0 &&
      totalWeight > 0 &&
      needsAttentionFactor >= 0 &&
      needsAttentionFactor <= 1 &&
      needsAttentionThreshold >= 0 &&
      needsAttentionThreshold <= 1 &&
      readyThreshold >= 0 &&
      readyThreshold <= 1 &&
      needsAttentionThreshold <= readyThreshold;
}

class TripReadinessScoringResult {
  const TripReadinessScoringResult({
    required this.assessment,
    required this.effectiveCategoryWeights,
  });

  final TripReadinessAssessment assessment;

  /// Chá»‰ chá»©a cÃ¡c category thá»±c sá»± cÃ³ item Ä‘Æ°á»£c tÃ­nh Ä‘iá»ƒm.
  final Map<TripReadinessCategory, double> effectiveCategoryWeights;
}

class TripReadinessScorer {
  const TripReadinessScorer();

  TripReadinessScoringResult? score({
    required List<TripReadinessItem> items,
    DateTime? assessedAt,
    bool recommendedBeforeDeparture = true,
    TripReadinessScoringPolicy policy = const TripReadinessScoringPolicy(),
    Map<TripReadinessCategory, double> categoryScoreOverrides = const {},
  }) {
    if (items.isEmpty ||
        !policy.isValid ||
        !_validCategoryScoreOverrides(categoryScoreOverrides)) {
      return null;
    }

    final summaries = <TripReadinessCategorySummary>[];
    final effectiveWeights = <TripReadinessCategory, double>{};

    var weightedScoreSum = 0.0;
    var effectiveWeightSum = 0.0;

    for (final category in TripReadinessCategory.values) {
      final categoryItems = items
          .where((item) => item.category == category)
          .toList(growable: false);

      if (categoryItems.isEmpty) {
        continue;
      }

      final summary = _scoreCategory(
        category: category,
        items: categoryItems,
        policy: policy,
        scoreOverride: categoryScoreOverrides[category],
      );

      summaries.add(summary);

      final weight = policy.weightFor(category);

      if (weight <= 0) {
        continue;
      }

      effectiveWeights[category] = weight;
      effectiveWeightSum += weight;
      weightedScoreSum += summary.score * weight;
    }

    if (effectiveWeightSum <= 0) {
      return null;
    }

    final score = (weightedScoreSum / effectiveWeightSum).clamp(0.0, 1.0);

    final level = _resolveOverallLevel(
      score: score,
      items: items,
      policy: policy,
    );

    return TripReadinessScoringResult(
      assessment: TripReadinessAssessment(
        level: level,
        score: score,
        items: List<TripReadinessItem>.unmodifiable(items),
        categorySummaries: List<TripReadinessCategorySummary>.unmodifiable(
          summaries,
        ),
        assessedAt: assessedAt?.toUtc(),
        recommendedBeforeDeparture: recommendedBeforeDeparture,
      ),
      effectiveCategoryWeights: Map<TripReadinessCategory, double>.unmodifiable(
        effectiveWeights,
      ),
    );
  }

  TripReadinessCategorySummary _scoreCategory({
    required TripReadinessCategory category,
    required List<TripReadinessItem> items,
    required TripReadinessScoringPolicy policy,
    double? scoreOverride,
  }) {
    final applicableItems = items
        .where((item) => item.status != TripReadinessItemStatus.notApplicable)
        .toList(growable: false);

    final calculatedScore = applicableItems.isEmpty
        ? 1.0
        : applicableItems
                  .map((item) => _statusFactor(item.status, policy))
                  .fold<double>(0, (sum, value) => sum + value) /
              applicableItems.length;

    final score = scoreOverride ?? calculatedScore;

    final blockingCount = items.where((item) => item.blocksReadiness).length;

    final attentionCount = items
        .where((item) => item.status == TripReadinessItemStatus.needsAttention)
        .length;

    final requiredItems = items
        .where((item) => item.isRequired)
        .toList(growable: false);

    final readyRequiredCount = requiredItems
        .where((item) => item.isReady)
        .length;

    final level = _resolveCategoryLevel(
      score: score,
      items: items,
      policy: policy,
    );

    return TripReadinessCategorySummary(
      category: category,
      level: level,
      score: score,
      itemCount: items.length,
      requiredItemCount: requiredItems.length,
      readyRequiredItemCount: readyRequiredCount,
      blockingItemCount: blockingCount,
      attentionItemCount: attentionCount,
    );
  }

  bool _validCategoryScoreOverrides(
    Map<TripReadinessCategory, double> overrides,
  ) {
    for (final value in overrides.values) {
      if (!value.isFinite || value < 0 || value > 1) {
        return false;
      }
    }

    return true;
  }

  double _statusFactor(
    TripReadinessItemStatus status,
    TripReadinessScoringPolicy policy,
  ) {
    switch (status) {
      case TripReadinessItemStatus.ready:
      case TripReadinessItemStatus.notApplicable:
        return 1;
      case TripReadinessItemStatus.needsAttention:
        return policy.needsAttentionFactor;
      case TripReadinessItemStatus.unknown:
      case TripReadinessItemStatus.missing:
        return 0;
    }
  }

  TripReadinessLevel _resolveCategoryLevel({
    required double score,
    required List<TripReadinessItem> items,
    required TripReadinessScoringPolicy policy,
  }) {
    if (items.any((item) => item.blocksReadiness)) {
      return TripReadinessLevel.notReady;
    }

    if (items.any((item) => item.preventsReady)) {
      return TripReadinessLevel.needsAttention;
    }

    if (score >= policy.readyThreshold) {
      return TripReadinessLevel.ready;
    }

    if (score < policy.needsAttentionThreshold) {
      return TripReadinessLevel.notReady;
    }

    return TripReadinessLevel.needsAttention;
  }

  TripReadinessLevel _resolveOverallLevel({
    required double score,
    required List<TripReadinessItem> items,
    required TripReadinessScoringPolicy policy,
  }) {
    if (items.any((item) => item.blocksReadiness)) {
      return TripReadinessLevel.notReady;
    }

    if (items.any((item) => item.preventsReady)) {
      return TripReadinessLevel.needsAttention;
    }

    if (score >= policy.readyThreshold) {
      return TripReadinessLevel.ready;
    }

    if (score < policy.needsAttentionThreshold) {
      return TripReadinessLevel.notReady;
    }

    return TripReadinessLevel.needsAttention;
  }
}
