import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_evidence_collector.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_evidence_provider.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_route_analyzer.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_route_sampler.dart';

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

  group('ConnectivityRiskEvidenceCollector', () {
    const collector = ConnectivityRiskEvidenceCollector();

    const location = ConnectivityRiskSampleLocation(
      latitude: 21,
      longitude: 105,
      distanceFromStartMeters: 10000,
      progressRatio: 0.1,
    );

    test('collects evidence from multiple providers', () async {
      final providers = [
        _FakeProvider(
          providerId: 'coverage',
          evidence: [
            evidence(
              type: ConnectivityRiskEvidenceType.mobileCoverage,
              risk: 0.8,
            ),
          ],
        ),
        _FakeProvider(
          providerId: 'terrain',
          evidence: [
            evidence(type: ConnectivityRiskEvidenceType.terrain, risk: 0.4),
          ],
        ),
      ];

      final result = await collector.collect(
        location: location,
        providers: providers,
      );

      expect(result.evidence.length, 2);
      expect(result.successfulProviders, ['coverage', 'terrain']);
      expect(result.failedProviders, isEmpty);
      expect(result.hasEvidence, isTrue);
      expect(result.hasFailures, isFalse);
    });

    test('keeps successful evidence when one provider fails', () async {
      final providers = [
        _FakeProvider(
          providerId: 'coverage',
          evidence: [
            evidence(
              type: ConnectivityRiskEvidenceType.mobileCoverage,
              risk: 0.8,
            ),
          ],
        ),
        _FakeProvider(providerId: 'terrain', shouldFail: true),
      ];

      final result = await collector.collect(
        location: location,
        providers: providers,
      );

      expect(result.evidence.length, 1);
      expect(result.successfulProviders, ['coverage']);
      expect(result.failedProviders, ['terrain']);
      expect(result.hasEvidence, isTrue);
      expect(result.hasFailures, isTrue);
      expect(result.allProvidersFailed, isFalse);
    });

    test('reports all providers failed', () async {
      final result = await collector.collect(
        location: location,
        providers: [
          _FakeProvider(providerId: 'A', shouldFail: true),
          _FakeProvider(providerId: 'B', shouldFail: true),
        ],
      );

      expect(result.evidence, isEmpty);
      expect(result.successfulProviders, isEmpty);
      expect(result.failedProviders, ['A', 'B']);
      expect(result.allProvidersFailed, isTrue);
    });

    test('handles empty provider list', () async {
      final result = await collector.collect(
        location: location,
        providers: const [],
      );

      expect(result.evidence, isEmpty);
      expect(result.successfulProviders, isEmpty);
      expect(result.failedProviders, isEmpty);
    });
  });

  group('ConnectivityRiskRouteAnalyzer', () {
    const analyzer = ConnectivityRiskRouteAnalyzer();

    test('runs full route analysis pipeline', () async {
      final provider = _DynamicProvider(
        providerId: 'dynamic',
        onGetEvidence: (location) {
          final risk = location.progressRatio < 0.5 ? 0.2 : 0.8;

          return [
            evidence(
              type: ConnectivityRiskEvidenceType.mobileCoverage,
              risk: risk,
            ),
          ];
        },
      );

      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        providers: [provider],
        samplingPolicy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 20000,
        ),
      );

      expect(result.hasAssessment, isTrue);
      expect(result.sampleCount, greaterThan(2));
      expect(result.scoredPointCount, result.sampleCount);
      expect(result.unscoredSampleCount, 0);

      final assessment = result.assessment!;

      expect(assessment.segments.length, greaterThanOrEqualTo(2));
      expect(assessment.hasWarningSegments, isTrue);
      expect(
        assessment.highestRiskSegment!.level,
        ConnectivityRiskLevel.critical,
      );
    });

    test(
      'keeps partial route analysis when provider fails on some samples',
      () async {
        var call = 0;

        final provider = _DynamicProvider(
          providerId: 'flaky',
          onGetEvidence: (location) {
            call++;

            if (call == 2) {
              throw Exception('temporary failure');
            }

            return [
              evidence(
                type: ConnectivityRiskEvidenceType.mobileCoverage,
                risk: 0.6,
              ),
            ];
          },
        );

        final result = await analyzer.analyze(
          routePoints: [routePoint(0, 0), routePoint(0, 1)],
          providers: [provider],
          samplingPolicy: const ConnectivityRiskSamplingPolicy(
            sampleSpacingMeters: 30000,
          ),
        );

        expect(result.hasAssessment, isTrue);
        expect(result.scoredPointCount, greaterThan(0));
        expect(result.unscoredSampleCount, 1);
        expect(result.providerFailureCount, 1);
        expect(result.failedProviderIds, contains('flaky'));
        expect(result.hasPartialData, isTrue);
        expect(result.hasProviderFailures, isTrue);
      },
    );

    test('can combine independent evidence providers', () async {
      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        providers: [
          _FakeProvider(
            providerId: 'coverage',
            evidence: [
              evidence(
                type: ConnectivityRiskEvidenceType.mobileCoverage,
                risk: 0.8,
              ),
            ],
          ),
          _FakeProvider(
            providerId: 'terrain',
            evidence: [
              evidence(type: ConnectivityRiskEvidenceType.terrain, risk: 0.2),
            ],
          ),
        ],
        samplingPolicy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 20000,
        ),
      );

      expect(result.hasAssessment, isTrue);
      expect(result.providerFailureCount, 0);
      expect(result.scoredPointCount, result.sampleCount);

      final score = result.assessment!.overallRiskScore;

      expect(score, greaterThan(0.5));
      expect(score, lessThan(0.8));
    });

    test('returns no assessment when all evidence is unavailable', () async {
      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        providers: [_FakeProvider(providerId: 'empty', evidence: const [])],
        samplingPolicy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 30000,
        ),
      );

      expect(result.assessment, isNull);
      expect(result.scoredPointCount, 0);
      expect(result.unscoredSampleCount, result.sampleCount);
    });

    test('returns no assessment when every provider fails', () async {
      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        providers: [_FakeProvider(providerId: 'broken', shouldFail: true)],
        samplingPolicy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 30000,
        ),
      );

      expect(result.assessment, isNull);
      expect(result.scoredPointCount, 0);
      expect(result.providerFailureCount, result.sampleCount);
      expect(result.failedProviderIds, {'broken'});
    });

    test('returns no assessment for invalid route', () async {
      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0)],
        providers: [
          _FakeProvider(
            providerId: 'coverage',
            evidence: [
              evidence(
                type: ConnectivityRiskEvidenceType.mobileCoverage,
                risk: 0.5,
              ),
            ],
          ),
        ],
      );

      expect(result.sampleCount, 0);
      expect(result.assessment, isNull);
    });

    test('returns no assessment when provider list is empty', () async {
      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        providers: const [],
        samplingPolicy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 30000,
        ),
      );

      expect(result.sampleCount, greaterThan(0));
      expect(result.assessment, isNull);
      expect(result.scoredPointCount, 0);
      expect(result.unscoredSampleCount, result.sampleCount);
    });

    test('preserves provider label and generated time', () async {
      final generatedAt = DateTime.utc(2026, 10, 24);

      final result = await analyzer.analyze(
        routePoints: [routePoint(0, 0), routePoint(0, 0.5)],
        providers: [
          _FakeProvider(
            providerId: 'coverage',
            evidence: [
              evidence(
                type: ConnectivityRiskEvidenceType.mobileCoverage,
                risk: 0.3,
              ),
            ],
          ),
        ],
        samplingPolicy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 20000,
        ),
        providerLabel: 'test-composite',
        generatedAt: generatedAt,
      );

      expect(result.assessment, isNotNull);
      expect(result.assessment!.provider, 'test-composite');
      expect(result.assessment!.generatedAt, generatedAt);
    });
  });
}

class _FakeProvider implements ConnectivityRiskEvidenceProvider {
  _FakeProvider({
    required this.providerId,
    this.evidence = const [],
    this.shouldFail = false,
  });

  @override
  final String providerId;

  final List<ConnectivityRiskEvidence> evidence;
  final bool shouldFail;

  @override
  Future<List<ConnectivityRiskEvidence>> getEvidence(
    ConnectivityRiskSampleLocation location,
  ) async {
    if (shouldFail) {
      throw Exception('provider failed');
    }

    return evidence;
  }
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
