import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import 'along_route_service.dart';
import 'geoapify_along_route_service.dart';

final alongRouteHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();

  ref.onDispose(client.close);

  return client;
});

final alongRouteServiceProvider = Provider<AlongRouteService>((ref) {
  final client = ref.watch(alongRouteHttpClientProvider);

  return GeoapifyAlongRouteService(client, apiKey: AppConfig.geoapifyApiKey);
});
