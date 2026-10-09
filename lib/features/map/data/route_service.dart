import '../domain/route_result.dart';

abstract class RouteService {
  Future<RouteResult> getRoute({
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  });
}
