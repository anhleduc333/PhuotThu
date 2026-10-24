import 'dart:math' as math;

import '../../map/data/along_route_service.dart';
import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';
import '../domain/rest_policy_calculator.dart';

class SmartRestPlaceSearchResult {
  const SmartRestPlaceSearchResult({
    required this.places,
    required this.targetCount,
    required this.successfulTargets,
    required this.failedTargets,
  });

  final List<AlongRoutePlace> places;
  final int targetCount;
  final int successfulTargets;
  final int failedTargets;

  bool get hasPartialFailures => failedTargets > 0 && successfulTargets > 0;

  bool get allTargetSearchesFailed =>
      targetCount > 0 && failedTargets == targetCount;
}

class SmartRestPlaceSearcher {
  const SmartRestPlaceSearcher();

  static const double _earthRadiusMeters = 6371000;
  static const double _defaultWindowMeters = 25000;

  Future<SmartRestPlaceSearchResult> search({
    required AlongRouteService service,
    required List<RoutePoint> routePoints,
    required List<RestTarget> targets,
    Set<AlongRoutePlaceType> types = const {
      AlongRoutePlaceType.restArea,
      AlongRoutePlaceType.food,
    },
    double searchRadiusMeters = 2000,
    double targetWindowMeters = _defaultWindowMeters,
    int maxResultsPerTarget = 30,
  }) async {
    final eligibleTypes = types
        .where(
          (type) =>
              type == AlongRoutePlaceType.restArea ||
              type == AlongRoutePlaceType.food,
        )
        .toSet();

    if (routePoints.length < 2 ||
        targets.isEmpty ||
        eligibleTypes.isEmpty ||
        targetWindowMeters <= 0 ||
        maxResultsPerTarget <= 0) {
      return const SmartRestPlaceSearchResult(
        places: [],
        targetCount: 0,
        successfulTargets: 0,
        failedTargets: 0,
      );
    }

    final cumulativeDistances = _buildCumulativeDistances(routePoints);
    final totalRouteMeters = cumulativeDistances.last;

    if (totalRouteMeters <= 0) {
      return const SmartRestPlaceSearchResult(
        places: [],
        targetCount: 0,
        successfulTargets: 0,
        failedTargets: 0,
      );
    }

    final deduplicated = <String, AlongRoutePlace>{};
    var successfulTargets = 0;
    var failedTargets = 0;

    for (final target in targets) {
      final segment = _segmentAroundTarget(
        routePoints: routePoints,
        cumulativeDistances: cumulativeDistances,
        totalRouteMeters: totalRouteMeters,
        targetDistanceMeters: target.targetDistanceMeters,
        targetWindowMeters: targetWindowMeters,
      );

      if (segment.length < 2) {
        failedTargets++;
        continue;
      }

      try {
        final result = await service.search(
          routePoints: segment,
          types: eligibleTypes,
          searchRadiusMeters: searchRadiusMeters,
          maxResults: maxResultsPerTarget,
        );

        successfulTargets++;

        for (final place in result.places) {
          if (!eligibleTypes.contains(place.type)) {
            continue;
          }

          final key = '${place.source}:${place.sourceId}';
          final existing = deduplicated[key];

          if (existing == null) {
            deduplicated[key] = place;
            continue;
          }

          final existingDistance =
              existing.distanceFromRouteMeters ?? double.infinity;
          final newDistance = place.distanceFromRouteMeters ?? double.infinity;

          if (newDistance < existingDistance) {
            deduplicated[key] = place;
          }
        }
      } catch (_) {
        failedTargets++;
      }
    }

    return SmartRestPlaceSearchResult(
      places: List<AlongRoutePlace>.unmodifiable(deduplicated.values),
      targetCount: targets.length,
      successfulTargets: successfulTargets,
      failedTargets: failedTargets,
    );
  }

  List<double> _buildCumulativeDistances(List<RoutePoint> routePoints) {
    final cumulativeDistances = List<double>.filled(routePoints.length, 0);

    for (var i = 1; i < routePoints.length; i++) {
      cumulativeDistances[i] =
          cumulativeDistances[i - 1] +
          _haversineMeters(routePoints[i - 1], routePoints[i]);
    }

    return cumulativeDistances;
  }

  List<RoutePoint> _segmentAroundTarget({
    required List<RoutePoint> routePoints,
    required List<double> cumulativeDistances,
    required double totalRouteMeters,
    required double targetDistanceMeters,
    required double targetWindowMeters,
  }) {
    final clampedTarget = targetDistanceMeters
        .clamp(0.0, totalRouteMeters)
        .toDouble();

    final startMeters = math.max(0.0, clampedTarget - targetWindowMeters);

    final endMeters = math.min(
      totalRouteMeters,
      clampedTarget + targetWindowMeters,
    );

    final startIndex = _startIndexForDistance(cumulativeDistances, startMeters);

    final endIndex = _endIndexForDistance(
      cumulativeDistances,
      endMeters,
      startIndex,
    );

    if (endIndex <= startIndex) {
      return const [];
    }

    return List<RoutePoint>.unmodifiable(
      routePoints.sublist(startIndex, endIndex + 1),
    );
  }

  int _startIndexForDistance(
    List<double> cumulativeDistances,
    double targetMeters,
  ) {
    var index = 0;

    while (index + 1 < cumulativeDistances.length &&
        cumulativeDistances[index + 1] <= targetMeters) {
      index++;
    }

    return index;
  }

  int _endIndexForDistance(
    List<double> cumulativeDistances,
    double targetMeters,
    int startIndex,
  ) {
    var index = math.max(startIndex + 1, 1).toInt();

    while (index < cumulativeDistances.length - 1 &&
        cumulativeDistances[index] < targetMeters) {
      index++;
    }

    return index.clamp(startIndex + 1, cumulativeDistances.length - 1).toInt();
  }

  double _haversineMeters(RoutePoint a, RoutePoint b) {
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);
    final deltaLatitude = _degreesToRadians(b.latitude - a.latitude);
    final deltaLongitude = _degreesToRadians(b.longitude - a.longitude);

    final sinLatitude = math.sin(deltaLatitude / 2);
    final sinLongitude = math.sin(deltaLongitude / 2);

    final haversine =
        sinLatitude * sinLatitude +
        math.cos(lat1) * math.cos(lat2) * sinLongitude * sinLongitude;

    final angularDistance =
        2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));

    return _earthRadiusMeters * angularDistance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
