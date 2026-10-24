import 'connectivity_risk.dart';
import 'connectivity_risk_evidence_provider.dart';

class ConnectivityRiskEvidenceCollection {
  const ConnectivityRiskEvidenceCollection({
    required this.location,
    required this.evidence,
    required this.successfulProviders,
    required this.failedProviders,
  });

  final ConnectivityRiskSampleLocation location;
  final List<ConnectivityRiskEvidence> evidence;

  final List<String> successfulProviders;
  final List<String> failedProviders;

  bool get hasEvidence => evidence.isNotEmpty;

  bool get hasFailures => failedProviders.isNotEmpty;

  bool get allProvidersFailed =>
      successfulProviders.isEmpty && failedProviders.isNotEmpty;
}

class ConnectivityRiskEvidenceCollector {
  const ConnectivityRiskEvidenceCollector();

  Future<ConnectivityRiskEvidenceCollection> collect({
    required ConnectivityRiskSampleLocation location,
    required List<ConnectivityRiskEvidenceProvider> providers,
  }) async {
    if (providers.isEmpty) {
      return ConnectivityRiskEvidenceCollection(
        location: location,
        evidence: const [],
        successfulProviders: const [],
        failedProviders: const [],
      );
    }

    final evidence = <ConnectivityRiskEvidence>[];
    final successfulProviders = <String>[];
    final failedProviders = <String>[];

    for (final provider in providers) {
      try {
        final result = await provider.getEvidence(location);

        successfulProviders.add(provider.providerId);

        for (final item in result) {
          evidence.add(item);
        }
      } catch (_) {
        failedProviders.add(provider.providerId);
      }
    }

    return ConnectivityRiskEvidenceCollection(
      location: location,
      evidence: List<ConnectivityRiskEvidence>.unmodifiable(evidence),
      successfulProviders: List<String>.unmodifiable(successfulProviders),
      failedProviders: List<String>.unmodifiable(failedProviders),
    );
  }
}
