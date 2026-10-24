import 'dart:math' as math;

import '../../map/domain/route_result.dart';
import '../domain/connectivity_risk.dart';

class ConnectivityRiskMapSegment {
  const ConnectivityRiskMapSegment({
    required this.level,
    required this.startDistanceMeters,
    required this.endDistanceMeters,
    required this.averageRiskScore,
    required this.maxRiskScore,
    required this.points,
  });

  final ConnectivityRiskLevel level;
  final double startDistanceMeters;
  final double endDistanceMeters;
  final double averageRiskScore;
  final double maxRiskScore;
  final List<RoutePoint> points;

  double get lengthMeters => endDistanceMeters - startDistanceMeters;

  double get lengthKm => lengthMeters / 1000;
}

class ConnectivityRiskMapSegmentBuilder {
  const ConnectivityRiskMapSegmentBuilder();

  static const double _earthRadiusMeters = 6371000;

  List<ConnectivityRiskMapSegment> build({
    required List<RoutePoint> routePoints,
    required ConnectivityRiskAssessment assessment,
  }) {
    if (routePoints.length < 2 ||
        assessment.totalRouteMeters <= 0 ||
        assessment.segments.isEmpty) {
      return const [];
    }

    final cumulative = _buildCumulativeDistances(routePoints);
    final routeLengthMeters = cumulative.last;

    if (routeLengthMeters <= 0) {
      return const [];
    }

    final result = <ConnectivityRiskMapSegment>[];

    for (final riskSegment in assessment.segments) {
      final start = riskSegment.startDistanceMeters.clamp(
        0.0,
        routeLengthMeters,
      );
      final end = riskSegment.endDistanceMeters.clamp(0.0, routeLengthMeters);

      if (end <= start) {
        continue;
      }

      final points = _sliceRoute(
        routePoints: routePoints,
        cumulativeDistances: cumulative,
        startDistanceMeters: start,
        endDistanceMeters: end,
      );

      if (points.length < 2) {
        continue;
      }

      result.add(
        ConnectivityRiskMapSegment(
          level: riskSegment.level,
          startDistanceMeters: start,
          endDistanceMeters: end,
          averageRiskScore: riskSegment.averageRiskScore,
          maxRiskScore: riskSegment.maxRiskScore,
          points: List<RoutePoint>.unmodifiable(points),
        ),
      );
    }

    return List<ConnectivityRiskMapSegment>.unmodifiable(result);
  }

  List<RoutePoint> _sliceRoute({
    required List<RoutePoint> routePoints,
    required List<double> cumulativeDistances,
    required double startDistanceMeters,
    required double endDistanceMeters,
  }) {
    final points = <RoutePoint>[];

    final startPoint = _pointAtDistance(
      routePoints: routePoints,
      cumulativeDistances: cumulativeDistances,
      distanceMeters: startDistanceMeters,
    );

    final endPoint = _pointAtDistance(
      routePoints: routePoints,
      cumulativeDistances: cumulativeDistances,
      distanceMeters: endDistanceMeters,
    );

    points.add(startPoint);

    for (var index = 1; index < routePoints.length - 1; index++) {
      final distance = cumulativeDistances[index];

      if (distance > startDistanceMeters && distance < endDistanceMeters) {
        points.add(routePoints[index]);
      }
    }

    if (!_sameCoordinate(points.last, endPoint)) {
      points.add(endPoint);
    }

    return points;
  }

  RoutePoint _pointAtDistance({
    required List<RoutePoint> routePoints,
    required List<double> cumulativeDistances,
    required double distanceMeters,
  }) {
    if (distanceMeters <= 0) {
      return routePoints.first;
    }

    final total = cumulativeDistances.last;

    if (distanceMeters >= total) {
      return routePoints.last;
    }

    var segmentIndex = 0;

    while (segmentIndex < routePoints.length - 2 &&
        cumulativeDistances[segmentIndex + 1] < distanceMeters) {
      segmentIndex++;
    }

    final segmentStartDistance = cumulativeDistances[segmentIndex];
    final segmentEndDistance = cumulativeDistances[segmentIndex + 1];
    final segmentLength = segmentEndDistance - segmentStartDistance;

    if (segmentLength <= 0) {
      return routePoints[segmentIndex];
    }

    final ratio = ((distanceMeters - segmentStartDistance) / segmentLength)
        .clamp(0.0, 1.0);

    final start = routePoints[segmentIndex];
    final end = routePoints[segmentIndex + 1];

    return RoutePoint(
      latitude: start.latitude + (end.latitude - start.latitude) * ratio,
      longitude: start.longitude + (end.longitude - start.longitude) * ratio,
    );
  }

  List<double> _buildCumulativeDistances(List<RoutePoint> routePoints) {
    final result = <double>[0];

    var total = 0.0;

    for (var index = 1; index < routePoints.length; index++) {
      total += _haversineMeters(
        routePoints[index - 1].latitude,
        routePoints[index - 1].longitude,
        routePoints[index].latitude,
        routePoints[index].longitude,
      );

      result.add(total);
    }

    return result;
  }

  double _haversineMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    final lat1 = latitude1 * math.pi / 180;
    final lat2 = latitude2 * math.pi / 180;
    final deltaLat = (latitude2 - latitude1) * math.pi / 180;
    final deltaLon = (longitude2 - longitude1) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  bool _sameCoordinate(RoutePoint first, RoutePoint second) {
    return (first.latitude - second.latitude).abs() < 0.0000001 &&
        (first.longitude - second.longitude).abs() < 0.0000001;
  }
}
