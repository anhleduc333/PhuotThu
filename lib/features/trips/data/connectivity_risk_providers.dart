import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../domain/connectivity_risk_evidence_provider.dart';
import '../domain/connectivity_risk_route_analyzer.dart';
import 'connectivity_risk_service.dart';
import 'geoapify_human_presence_risk_provider.dart';
import 'open_meteo_terrain_risk_provider.dart';

final connectivityRiskHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();

  ref.onDispose(client.close);

  return client;
});

final terrainRiskEvidenceProvider = Provider<ConnectivityRiskEvidenceProvider>((
  ref,
) {
  final client = ref.watch(connectivityRiskHttpClientProvider);

  return OpenMeteoTerrainRiskProvider(client);
});

final humanPresenceRiskEvidenceProvider =
    Provider<ConnectivityRiskEvidenceProvider>((ref) {
      final client = ref.watch(connectivityRiskHttpClientProvider);

      return GeoapifyHumanPresenceRiskProvider(
        client,
        apiKey: AppConfig.geoapifyApiKey,
      );
    });

final connectivityRiskEvidenceProvidersProvider =
    Provider<List<ConnectivityRiskEvidenceProvider>>((ref) {
      return List<ConnectivityRiskEvidenceProvider>.unmodifiable([
        ref.watch(terrainRiskEvidenceProvider),
        ref.watch(humanPresenceRiskEvidenceProvider),
      ]);
    });

final connectivityRiskRouteAnalyzerProvider =
    Provider<ConnectivityRiskRouteAnalyzer>((ref) {
      return const ConnectivityRiskRouteAnalyzer();
    });

final connectivityRiskServiceProvider = Provider<ConnectivityRiskService>((
  ref,
) {
  return ConnectivityRiskService(
    analyzer: ref.watch(connectivityRiskRouteAnalyzerProvider),
    providers: ref.watch(connectivityRiskEvidenceProvidersProvider),
  );
});
