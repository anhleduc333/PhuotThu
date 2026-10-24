import 'dart:math' as math;

import '../../map/domain/route_result.dart';

class RouteProgressEstimate {
  const RouteProgressEstimate({
    required this.totalRouteMeters,
    required this.distanceFromStartMeters,
    required this.distanceToEndMeters,
    required this.distanceFromRouteMeters,
    required this.progressRatio,
    required this.segmentIndex,
    required this.projectedLatitude,
    required this.projectedLongitude,
  });

  /// Tổng chiều dài polyline được tính từ các điểm route.
  final double totalRouteMeters;

  /// POI nằm tại vị trí khoảng bao nhiêu mét
  /// tính từ điểm xuất phát dọc theo tuyến.
  final double distanceFromStartMeters;

  /// Quãng đường còn lại từ vị trí POI tới đích.
  final double distanceToEndMeters;

  /// Khoảng cách vuông góc gần nhất từ POI tới tuyến.
  final double distanceFromRouteMeters;

  /// Tiến độ trên tuyến.
  ///
  /// 0.0 = điểm xuất phát.
  /// 1.0 = điểm đến.
  final double progressRatio;

  /// Segment gần POI nhất.
  ///
  /// Ví dụ segmentIndex = 0 nghĩa là đoạn:
  /// routePoints[0] -> routePoints[1].
  final int segmentIndex;

  /// Điểm chiếu gần nhất của POI lên tuyến.
  final double projectedLatitude;
  final double projectedLongitude;

  double get totalRouteKm => totalRouteMeters / 1000;

  double get distanceFromStartKm => distanceFromStartMeters / 1000;

  double get distanceToEndKm => distanceToEndMeters / 1000;

  double get distanceFromRouteKm => distanceFromRouteMeters / 1000;

  double get progressPercent => progressRatio * 100;

  bool isWithinCorridorMeters(double maxDistanceMeters) {
    if (maxDistanceMeters < 0) {
      return false;
    }

    return distanceFromRouteMeters <= maxDistanceMeters;
  }
}

class RouteProgressCalculator {
  const RouteProgressCalculator();

  static const double _earthRadiusMeters = 6371000;

  RouteProgressEstimate? calculate({
    required List<RoutePoint> routePoints,
    required double latitude,
    required double longitude,
  }) {
    if (routePoints.length < 2) {
      return null;
    }

    if (!_isValidCoordinate(latitude, longitude)) {
      return null;
    }

    final segmentLengths = <double>[];

    var totalRouteMeters = 0.0;

    for (var i = 1; i < routePoints.length; i++) {
      final length = _haversineMeters(routePoints[i - 1], routePoints[i]);

      segmentLengths.add(length);

      totalRouteMeters += length;
    }

    if (totalRouteMeters <= 0) {
      return null;
    }

    var bestDistance = double.infinity;

    var bestDistanceFromStart = 0.0;

    var bestSegmentIndex = 0;

    var bestProjectedLatitude = routePoints.first.latitude;

    var bestProjectedLongitude = routePoints.first.longitude;

    var cumulativeDistance = 0.0;

    for (var i = 0; i < segmentLengths.length; i++) {
      final start = routePoints[i];

      final end = routePoints[i + 1];

      final segmentLength = segmentLengths[i];

      if (segmentLength <= 0) {
        continue;
      }

      final projection = _projectPointToSegment(
        pointLatitude: latitude,
        pointLongitude: longitude,
        start: start,
        end: end,
      );

      if (projection.distanceMeters < bestDistance) {
        bestDistance = projection.distanceMeters;

        bestDistanceFromStart =
            cumulativeDistance + segmentLength * projection.segmentRatio;

        bestSegmentIndex = i;

        bestProjectedLatitude =
            start.latitude +
            (end.latitude - start.latitude) * projection.segmentRatio;

        bestProjectedLongitude =
            start.longitude +
            (end.longitude - start.longitude) * projection.segmentRatio;
      }

      cumulativeDistance += segmentLength;
    }

    if (!bestDistance.isFinite) {
      return null;
    }

    final clampedDistanceFromStart = bestDistanceFromStart
        .clamp(0.0, totalRouteMeters)
        .toDouble();

    final distanceToEnd = (totalRouteMeters - clampedDistanceFromStart)
        .clamp(0.0, totalRouteMeters)
        .toDouble();

    final progressRatio = (clampedDistanceFromStart / totalRouteMeters)
        .clamp(0.0, 1.0)
        .toDouble();

    return RouteProgressEstimate(
      totalRouteMeters: totalRouteMeters,
      distanceFromStartMeters: clampedDistanceFromStart,
      distanceToEndMeters: distanceToEnd,
      distanceFromRouteMeters: bestDistance,
      progressRatio: progressRatio,
      segmentIndex: bestSegmentIndex,
      projectedLatitude: bestProjectedLatitude,
      projectedLongitude: bestProjectedLongitude,
    );
  }

  _SegmentProjection _projectPointToSegment({
    required double pointLatitude,
    required double pointLongitude,
    required RoutePoint start,
    required RoutePoint end,
  }) {
    final referenceLatitude = _degreesToRadians(pointLatitude);

    final startX =
        _earthRadiusMeters *
        _degreesToRadians(start.longitude - pointLongitude) *
        math.cos(referenceLatitude);

    final startY =
        _earthRadiusMeters * _degreesToRadians(start.latitude - pointLatitude);

    final endX =
        _earthRadiusMeters *
        _degreesToRadians(end.longitude - pointLongitude) *
        math.cos(referenceLatitude);

    final endY =
        _earthRadiusMeters * _degreesToRadians(end.latitude - pointLatitude);

    final segmentX = endX - startX;

    final segmentY = endY - startY;

    final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

    if (segmentLengthSquared <= 0) {
      return _SegmentProjection(
        distanceMeters: math.sqrt(startX * startX + startY * startY),
        segmentRatio: 0,
      );
    }

    final segmentRatio =
        (-(startX * segmentX + startY * segmentY) / segmentLengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();

    final closestX = startX + segmentRatio * segmentX;

    final closestY = startY + segmentRatio * segmentY;

    final distance = math.sqrt(closestX * closestX + closestY * closestY);

    return _SegmentProjection(
      distanceMeters: distance,
      segmentRatio: segmentRatio,
    );
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

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.distanceMeters,
    required this.segmentRatio,
  });

  final double distanceMeters;
  final double segmentRatio;
}
