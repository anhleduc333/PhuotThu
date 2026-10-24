import '../../map/domain/route_result.dart';
import '../domain/connectivity_risk.dart';
import '../domain/connectivity_risk_evidence_provider.dart';
import '../domain/connectivity_risk_route_analyzer.dart';
import '../domain/connectivity_risk_route_sampler.dart';
import '../domain/connectivity_risk_scorer.dart';
import '../domain/connectivity_risk_zone_detector.dart';

class ConnectivityRiskAnalysisSummary {
  const ConnectivityRiskAnalysisSummary({
    required this.routeAnalysis,
    required this.samplingPolicy,
    required this.providerIds,
  });

  final ConnectivityRiskRouteAnalysisResult routeAnalysis;
  final ConnectivityRiskSamplingPolicy samplingPolicy;
  final List<String> providerIds;

  ConnectivityRiskAssessment? get assessment => routeAnalysis.assessment;

  bool get hasAssessment => assessment != null;

  bool get usesDirectMobileCoverage {
    final value = assessment;

    if (value == null) {
      return false;
    }

    return value.sampledPoints.any(
      (point) => point.evidence.any(
        (evidence) =>
            evidence.type == ConnectivityRiskEvidenceType.mobileCoverage,
      ),
    );
  }

  /// true khi đã có assessment nhưng chưa có evidence phủ sóng trực tiếp.
  bool get proxyOnly => hasAssessment && !usesDirectMobileCoverage;

  double get scoredSampleRatio {
    if (routeAnalysis.sampleCount <= 0) {
      return 0;
    }

    return (routeAnalysis.scoredPointCount / routeAnalysis.sampleCount).clamp(
      0.0,
      1.0,
    );
  }

  double get scoredSamplePercent => scoredSampleRatio * 100;

  String get dataQualityLabel {
    if (!hasAssessment) {
      return 'Chưa đủ dữ liệu';
    }

    if (routeAnalysis.hasPartialData || routeAnalysis.hasProviderFailures) {
      return 'Dữ liệu một phần';
    }

    if (proxyOnly) {
      return 'Ước lượng proxy';
    }

    return 'Có dữ liệu phủ sóng trực tiếp';
  }

  String get interpretationNotice {
    if (!hasAssessment) {
      return 'Chưa đủ dữ liệu để ước lượng nguy cơ kết nối trên tuyến.';
    }

    if (proxyOnly) {
      return 'Kết quả hiện là ước lượng từ địa hình, mật độ dấu hiệu '
          'dân cư/dịch vụ và mức độ biệt lập; không phải dữ liệu phủ sóng '
          'trực tiếp từ nhà mạng.';
    }

    return 'Kết quả có sử dụng evidence phủ sóng trực tiếp cùng các '
        'evidence hỗ trợ khác.';
  }
}

class ConnectivityRiskService {
  const ConnectivityRiskService({
    required this.analyzer,
    required this.providers,
  });

  final ConnectivityRiskRouteAnalyzer analyzer;
  final List<ConnectivityRiskEvidenceProvider> providers;

  ConnectivityRiskSamplingPolicy samplingPolicyForDistance(
    double routeDistanceMeters,
  ) {
    final distance = routeDistanceMeters.isFinite && routeDistanceMeters > 0
        ? routeDistanceMeters
        : 0.0;

    if (distance <= 150000) {
      return const ConnectivityRiskSamplingPolicy(
        sampleSpacingMeters: 15000,
        maximumSamples: 60,
      );
    }

    if (distance <= 400000) {
      return const ConnectivityRiskSamplingPolicy(
        sampleSpacingMeters: 20000,
        maximumSamples: 60,
      );
    }

    if (distance <= 800000) {
      return const ConnectivityRiskSamplingPolicy(
        sampleSpacingMeters: 30000,
        maximumSamples: 60,
      );
    }

    return const ConnectivityRiskSamplingPolicy(
      sampleSpacingMeters: 40000,
      maximumSamples: 60,
    );
  }

  Future<ConnectivityRiskAnalysisSummary> analyzeRoute({
    required List<RoutePoint> routePoints,
    required double routeDistanceMeters,
    DateTime? generatedAt,
    ConnectivityRiskScoringPolicy scoringPolicy =
        const ConnectivityRiskScoringPolicy(),
    ConnectivityRiskZonePolicy zonePolicy = const ConnectivityRiskZonePolicy(),
  }) async {
    final samplingPolicy = samplingPolicyForDistance(routeDistanceMeters);

    final providerIds = providers
        .map((provider) => provider.providerId)
        .toList(growable: false);

    final routeAnalysis = await analyzer.analyze(
      routePoints: routePoints,
      providers: providers,
      samplingPolicy: samplingPolicy,
      scoringPolicy: scoringPolicy,
      zonePolicy: zonePolicy,
      providerLabel: providerIds.isEmpty ? 'none' : providerIds.join('+'),
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
    );

    return ConnectivityRiskAnalysisSummary(
      routeAnalysis: routeAnalysis,
      samplingPolicy: samplingPolicy,
      providerIds: List<String>.unmodifiable(providerIds),
    );
  }
}
