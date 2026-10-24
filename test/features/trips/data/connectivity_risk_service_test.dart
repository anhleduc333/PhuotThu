import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/data/connectivity_risk_providers.dart';
import 'package:phuotthu/features/trips/data/connectivity_risk_service.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_evidence_provider.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_route_analyzer.dart';

void main() {
  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

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

  group('ConnectivityRiskService sampling policy', () {
    const service = ConnectivityRiskService(
      analyzer: ConnectivityRiskRouteAnalyzer(),
      providers: [],
    );

    test('uses 15 km spacing for short routes', () {
      final policy = service.samplingPolicyForDistance(100000);

      expect(policy.sampleSpacingMeters, 15000);
      expect(policy.maximumSamples, 60);
    });

    test('uses 20 km spacing for medium routes', () {
      final policy = service.samplingPolicyForDistance(300000);

      expect(policy.sampleSpacingMeters, 20000);
    });

    test('uses 30 km spacing for long routes', () {
      final policy = service.samplingPolicyForDistance(600000);

      expect(policy.sampleSpacingMeters, 30000);
    });

    test('uses 40 km spacing for very long routes', () {
      final policy = service.samplingPolicyForDistance(1200000);

      expect(policy.sampleSpacingMeters, 40000);
      expect(policy.maximumSamples, 60);
    });
  });

  group('ConnectivityRiskService analysis summary', () {
    test('marks proxy-only analysis when no mobile coverage exists', () async {
      final service = ConnectivityRiskService(
        analyzer: const ConnectivityRiskRouteAnalyzer(),
        providers: [
          _DynamicProvider(
            providerId: 'terrain',
            onGetEvidence: (location) => [
              evidence(
                type: ConnectivityRiskEvidenceType.terrain,
                risk: location.progressRatio < 0.5 ? 0.2 : 0.7,
                confidence: 0.55,
              ),
            ],
          ),
          _DynamicProvider(
            providerId: 'presence',
            onGetEvidence: (location) => [
              evidence(
                type: ConnectivityRiskEvidenceType.settlementDensity,
                risk: 0.5,
                confidence: 0.45,
              ),
              evidence(
                type: ConnectivityRiskEvidenceType.roadIsolation,
                risk: 0.6,
                confidence: 0.45,
              ),
            ],
          ),
        ],
      );

      final summary = await service.analyzeRoute(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        routeDistanceMeters: 111000,
        generatedAt: DateTime.utc(2026, 10, 24),
      );

      expect(summary.hasAssessment, isTrue);
      expect(summary.proxyOnly, isTrue);
      expect(summary.usesDirectMobileCoverage, isFalse);
      expect(summary.dataQualityLabel, 'Ước lượng proxy');
      expect(
        summary.interpretationNotice,
        contains('không phải dữ liệu phủ sóng trực tiếp'),
      );
      expect(summary.scoredSamplePercent, 100);
    });

    test('detects direct mobile coverage evidence', () async {
      final service = ConnectivityRiskService(
        analyzer: const ConnectivityRiskRouteAnalyzer(),
        providers: [
          _DynamicProvider(
            providerId: 'coverage',
            onGetEvidence: (location) => [
              evidence(
                type: ConnectivityRiskEvidenceType.mobileCoverage,
                risk: 0.4,
                confidence: 0.9,
              ),
            ],
          ),
        ],
      );

      final summary = await service.analyzeRoute(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        routeDistanceMeters: 55000,
      );

      expect(summary.hasAssessment, isTrue);
      expect(summary.usesDirectMobileCoverage, isTrue);
      expect(summary.proxyOnly, isFalse);
      expect(summary.dataQualityLabel, 'Có dữ liệu phủ sóng trực tiếp');
    });

    test('reports partial data when one sample cannot be scored', () async {
      var calls = 0;

      final service = ConnectivityRiskService(
        analyzer: const ConnectivityRiskRouteAnalyzer(),
        providers: [
          _DynamicProvider(
            providerId: 'flaky',
            onGetEvidence: (location) {
              calls++;

              if (calls == 2) {
                return const [];
              }

              return [
                evidence(
                  type: ConnectivityRiskEvidenceType.terrain,
                  risk: 0.5,
                  confidence: 0.55,
                ),
              ];
            },
          ),
        ],
      );

      final summary = await service.analyzeRoute(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        routeDistanceMeters: 55000,
      );

      expect(summary.hasAssessment, isTrue);
      expect(summary.routeAnalysis.hasPartialData, isTrue);
      expect(summary.dataQualityLabel, 'Dữ liệu một phần');
      expect(summary.scoredSampleRatio, lessThan(1));
    });

    test('returns no assessment when there are no providers', () async {
      const service = ConnectivityRiskService(
        analyzer: ConnectivityRiskRouteAnalyzer(),
        providers: [],
      );

      final summary = await service.analyzeRoute(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        routeDistanceMeters: 55000,
      );

      expect(summary.hasAssessment, isFalse);
      expect(summary.proxyOnly, isFalse);
      expect(summary.dataQualityLabel, 'Chưa đủ dữ liệu');
      expect(summary.scoredSampleRatio, 0);
    });

    test('preserves provider ids in summary and assessment label', () async {
      final service = ConnectivityRiskService(
        analyzer: const ConnectivityRiskRouteAnalyzer(),
        providers: [
          _DynamicProvider(
            providerId: 'terrain-x',
            onGetEvidence: (location) => [
              evidence(type: ConnectivityRiskEvidenceType.terrain, risk: 0.3),
            ],
          ),
          _DynamicProvider(
            providerId: 'presence-y',
            onGetEvidence: (location) => [
              evidence(
                type: ConnectivityRiskEvidenceType.roadIsolation,
                risk: 0.3,
              ),
            ],
          ),
        ],
      );

      final summary = await service.analyzeRoute(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        routeDistanceMeters: 55000,
      );

      expect(summary.providerIds, ['terrain-x', 'presence-y']);

      expect(summary.assessment!.provider, 'terrain-x+presence-y');
    });
  });

  group('Connectivity risk Riverpod wiring', () {
    test('wires two proxy evidence providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final providers = container.read(
        connectivityRiskEvidenceProvidersProvider,
      );

      expect(providers.length, 2);

      expect(providers.map((provider) => provider.providerId).toSet(), {
        'open-meteo-terrain-proxy',
        'geoapify-human-presence-proxy',
      });
    });

    test('wires route analyzer and service', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final analyzer = container.read(connectivityRiskRouteAnalyzerProvider);

      final service = container.read(connectivityRiskServiceProvider);

      expect(analyzer, isA<ConnectivityRiskRouteAnalyzer>());
      expect(service, isA<ConnectivityRiskService>());
      expect(service.providers.length, 2);
    });
  });
}

typedef _EvidenceHandler = List<ConnectivityRiskEvidence> Function(
  ConnectivityRiskSampleLocation location,
);

class _DynamicProvider implements ConnectivityRiskEvidenceProvider {
  _DynamicProvider({required this.providerId, required this.onGetEvidence});

  @override
  final String providerId;

  final _EvidenceHandler onGetEvidence;

  @override
  Future<List<ConnectivityRiskEvidence>> getEvidence(
    ConnectivityRiskSampleLocation location,
  ) async {
    return onGetEvidence(location);
  }
}
