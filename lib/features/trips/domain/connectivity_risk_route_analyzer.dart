import '../../map/domain/route_result.dart';
import 'connectivity_risk.dart';
import 'connectivity_risk_evidence_collector.dart';
import 'connectivity_risk_evidence_provider.dart';
import 'connectivity_risk_route_sampler.dart';
import 'connectivity_risk_scorer.dart';
import 'connectivity_risk_zone_detector.dart';

class ConnectivityRiskRouteAnalysisResult {
  const ConnectivityRiskRouteAnalysisResult({
    required this.assessment,
    required this.sampleCount,
    required this.scoredPointCount,
    required this.unscoredSampleCount,
    required this.providerFailureCount,
    required this.failedProviderIds,
  });

  final ConnectivityRiskAssessment? assessment;

  final int sampleCount;
  final int scoredPointCount;
  final int unscoredSampleCount;

  /// Tổng số lần provider lỗi trên toàn bộ sample.
  final int providerFailureCount;

  final Set<String> failedProviderIds;

  bool get hasAssessment => assessment != null;

  bool get hasPartialData => scoredPointCount > 0 && unscoredSampleCount > 0;

  bool get hasProviderFailures => providerFailureCount > 0;
}

class ConnectivityRiskRouteAnalyzer {
  const ConnectivityRiskRouteAnalyzer();

  Future<ConnectivityRiskRouteAnalysisResult> analyze({
    required List<RoutePoint> routePoints,
    required List<ConnectivityRiskEvidenceProvider> providers,
    ConnectivityRiskSamplingPolicy samplingPolicy =
        const ConnectivityRiskSamplingPolicy(),
    ConnectivityRiskScoringPolicy scoringPolicy =
        const ConnectivityRiskScoringPolicy(),
    ConnectivityRiskZonePolicy zonePolicy = const ConnectivityRiskZonePolicy(),
    String providerLabel = 'composite',
    DateTime? generatedAt,
  }) async {
    const sampler = ConnectivityRiskRouteSampler();

    final samples = sampler.sample(
      routePoints: routePoints,
      policy: samplingPolicy,
    );

    if (samples.isEmpty || providers.isEmpty) {
      return ConnectivityRiskRouteAnalysisResult(
        assessment: null,
        sampleCount: samples.length,
        scoredPointCount: 0,
        unscoredSampleCount: samples.length,
        providerFailureCount: 0,
        failedProviderIds: const {},
      );
    }

    const collector = ConnectivityRiskEvidenceCollector();
    const scorer = ConnectivityRiskScorer();

    final points = <ConnectivityRiskPoint>[];

    var unscoredSampleCount = 0;
    var providerFailureCount = 0;
    final failedProviderIds = <String>{};

    for (final sample in samples) {
      final collection = await collector.collect(
        location: sample,
        providers: providers,
      );

      providerFailureCount += collection.failedProviders.length;
      failedProviderIds.addAll(collection.failedProviders);

      final point = scorer.scorePoint(
        latitude: sample.latitude,
        longitude: sample.longitude,
        distanceFromStartMeters: sample.distanceFromStartMeters,
        progressRatio: sample.progressRatio,
        evidence: collection.evidence,
        policy: scoringPolicy,
      );

      if (point == null) {
        unscoredSampleCount++;
        continue;
      }

      points.add(point);
    }

    if (points.isEmpty) {
      return ConnectivityRiskRouteAnalysisResult(
        assessment: null,
        sampleCount: samples.length,
        scoredPointCount: 0,
        unscoredSampleCount: unscoredSampleCount,
        providerFailureCount: providerFailureCount,
        failedProviderIds: Set<String>.unmodifiable(failedProviderIds),
      );
    }

    final totalRouteMeters = samples.last.distanceFromStartMeters;

    const detector = ConnectivityRiskZoneDetector();

    final assessment = detector.detect(
      totalRouteMeters: totalRouteMeters,
      points: points,
      provider: providerLabel,
      generatedAt: generatedAt,
      policy: zonePolicy,
    );

    return ConnectivityRiskRouteAnalysisResult(
      assessment: assessment,
      sampleCount: samples.length,
      scoredPointCount: points.length,
      unscoredSampleCount: unscoredSampleCount,
      providerFailureCount: providerFailureCount,
      failedProviderIds: Set<String>.unmodifiable(failedProviderIds),
    );
  }
}
