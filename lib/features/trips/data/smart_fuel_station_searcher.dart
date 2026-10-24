import 'dart:math' as math;

import '../../map/data/along_route_service.dart';
import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';

class SmartFuelStationSearchResult {
  const SmartFuelStationSearchResult({
    required this.places,
    required this.segmentCount,
    required this.successfulSegments,
    required this.failedSegments,
  });

  final List<AlongRoutePlace> places;
  final int segmentCount;
  final int successfulSegments;
  final int failedSegments;

  bool get hasPartialFailures => failedSegments > 0 && successfulSegments > 0;

  bool get allSegmentsFailed =>
      segmentCount > 0 && failedSegments == segmentCount;
}

class SmartFuelStationSearcher {
  const SmartFuelStationSearcher();

  static const double _earthRadiusMeters = 6371000;
  static const double _minimumSegmentMeters = 50000;
  static const double _maximumSegmentMeters = 120000;
  static const double _segmentSafeRangeFactor = 0.55;
  static const double _maximumOverlapMeters = 15000;
  static const double _overlapRatio = 0.15;
  static const int _maximumSegments = 24;

  Future<SmartFuelStationSearchResult> search({
    required AlongRouteService service,
    required List<RoutePoint> routePoints,
    required double safeRangeMeters,
    double searchRadiusMeters = 2000,
    int maxResultsPerSegment = 20,
  }) async {
    if (routePoints.length < 2 || maxResultsPerSegment <= 0) {
      return const SmartFuelStationSearchResult(
        places: [],
        segmentCount: 0,
        successfulSegments: 0,
        failedSegments: 0,
      );
    }

    final segments = _buildSegments(
      routePoints: routePoints,
      safeRangeMeters: safeRangeMeters,
    );

    if (segments.isEmpty) {
      return const SmartFuelStationSearchResult(
        places: [],
        segmentCount: 0,
        successfulSegments: 0,
        failedSegments: 0,
      );
    }

    final deduplicated = <String, AlongRoutePlace>{};

    var successfulSegments = 0;
    var failedSegments = 0;

    for (final segment in segments) {
      try {
        final result = await service.search(
          routePoints: segment,
          types: const {AlongRoutePlaceType.fuel},
          searchRadiusMeters: searchRadiusMeters,
          maxResults: maxResultsPerSegment,
        );

        successfulSegments++;

        for (final place in result.places) {
          if (place.type != AlongRoutePlaceType.fuel) {
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
        failedSegments++;
      }
    }

    return SmartFuelStationSearchResult(
      places: List<AlongRoutePlace>.unmodifiable(deduplicated.values),
      segmentCount: segments.length,
      successfulSegments: successfulSegments,
      failedSegments: failedSegments,
    );
  }

  List<List<RoutePoint>> _buildSegments({
    required List<RoutePoint> routePoints,
    required double safeRangeMeters,
  }) {
    if (routePoints.length < 2) {
      return const [];
    }

    final cumulativeDistances = List<double>.filled(routePoints.length, 0);

    for (var i = 1; i < routePoints.length; i++) {
      cumulativeDistances[i] =
          cumulativeDistances[i - 1] +
          _haversineMeters(routePoints[i - 1], routePoints[i]);
    }

    final totalRouteMeters = cumulativeDistances.last;

    if (totalRouteMeters <= 0) {
      return const [];
    }

    final desiredSegmentMeters =
        (safeRangeMeters > 0
                ? safeRangeMeters * _segmentSafeRangeFactor
                : _minimumSegmentMeters)
            .clamp(_minimumSegmentMeters, _maximumSegmentMeters)
            .toDouble();

    var segmentCount = (totalRouteMeters / desiredSegmentMeters).ceil();

    segmentCount = segmentCount.clamp(1, _maximumSegments).toInt();

    final segmentMeters = totalRouteMeters / segmentCount;

    final overlapMeters = math.min(
      _maximumOverlapMeters,
      segmentMeters * _overlapRatio,
    );

    final segments = <List<RoutePoint>>[];

    for (var i = 0; i < segmentCount; i++) {
      final nominalStart = segmentMeters * i;
      final nominalEnd = segmentMeters * (i + 1);

      final startMeters = i == 0
          ? 0.0
          : math.max(0.0, nominalStart - overlapMeters);

      final endMeters = i == segmentCount - 1
          ? totalRouteMeters
          : math.min(totalRouteMeters, nominalEnd + overlapMeters);

      final startIndex = _startIndexForDistance(
        cumulativeDistances,
        startMeters,
      );

      final endIndex = _endIndexForDistance(
        cumulativeDistances,
        endMeters,
        startIndex,
      );

      if (endIndex <= startIndex) {
        continue;
      }

      segments.add(
        List<RoutePoint>.unmodifiable(
          routePoints.sublist(startIndex, endIndex + 1),
        ),
      );
    }

    return List<List<RoutePoint>>.unmodifiable(segments);
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
