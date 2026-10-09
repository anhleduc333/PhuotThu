import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'osrm_route_service.dart';
import 'route_service.dart';

final routeServiceProvider = Provider<RouteService>((ref) {
  final client = http.Client();

  ref.onDispose(client.close);

  return OsrmRouteService(client);
});
