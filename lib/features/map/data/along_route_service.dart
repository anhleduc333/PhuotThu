import '../domain/along_route_place.dart';
import '../domain/along_route_result.dart';
import '../domain/route_result.dart';

abstract class AlongRouteService {
  Future<AlongRouteResult> search({
    required List<RoutePoint> routePoints,

    Set<AlongRoutePlaceType> types = const {
      AlongRoutePlaceType.fuel,
      AlongRoutePlaceType.restArea,
      AlongRoutePlaceType.food,
      AlongRoutePlaceType.repair,
      AlongRoutePlaceType.medical,
    },

    double searchRadiusMeters = 3000,

    int maxResults = 50,
  });
}
