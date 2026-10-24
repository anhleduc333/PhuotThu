import 'dart:math' as math;

import '../../map/domain/route_result.dart';
import 'connectivity_risk_evidence_provider.dart';

class ConnectivityRiskSamplingPolicy {
  const ConnectivityRiskSamplingPolicy({
    this.sampleSpacingMeters = 10000,
    this.maximumSamples = 200,
    this.includeStart = true,
    this.includeEnd = true,
  });

  /// Khoảng cách mục tiêu giữa hai sample.
  final double sampleSpacingMeters;

  /// Giới hạn để tránh quá nhiều request tới provider dữ liệu.
  final int maximumSamples;

  final bool includeStart;
  final bool includeEnd;

  bool get isValid => sampleSpacingMeters > 0 && maximumSamples >= 2;
}

class ConnectivityRiskRouteSampler {
  const ConnectivityRiskRouteSampler();

  static const double _earthRadiusMeters = 6371000;

  List<ConnectivityRiskSampleLocation> sample({
    required List<RoutePoint> routePoints,
    ConnectivityRiskSamplingPolicy policy =
        const ConnectivityRiskSamplingPolicy(),
  }) {
    if (routePoints.length < 2 || !policy.isValid) {
      return const [];
    }

    final cumulative = _buildCumulativeDistances(routePoints);
    final totalRouteMeters = cumulative.last;

    if (totalRouteMeters <= 0) {
      return const [];
    }

    final targetDistances = _buildTargetDistances(
      totalRouteMeters: totalRouteMeters,
      policy: policy,
    );

    if (targetDistances.isEmpty) {
      return const [];
    }

    final samples = <ConnectivityRiskSampleLocation>[];

    var segmentIndex = 0;

    for (final targetDistance in targetDistances) {
      while (segmentIndex < routePoints.length - 2 &&
          cumulative[segmentIndex + 1] < targetDistance) {
        segmentIndex++;
      }

      final start = routePoints[segmentIndex];
      final end = routePoints[segmentIndex + 1];

      final segmentStartDistance = cumulative[segmentIndex];
      final segmentEndDistance = cumulative[segmentIndex + 1];
      final segmentLength = segmentEndDistance - segmentStartDistance;

      final ratio = segmentLength <= 0
          ? 0.0
          : ((targetDistance - segmentStartDistance) / segmentLength).clamp(
              0.0,
              1.0,
            );

      final latitude = start.latitude + (end.latitude - start.latitude) * ratio;
      final longitude =
          start.longitude + (end.longitude - start.longitude) * ratio;

      samples.add(
        ConnectivityRiskSampleLocation(
          latitude: latitude,
          longitude: longitude,
          distanceFromStartMeters: targetDistance,
          progressRatio: (targetDistance / totalRouteMeters).clamp(0.0, 1.0),
        ),
      );
    }

    return List<ConnectivityRiskSampleLocation>.unmodifiable(samples);
  }

  List<double> _buildTargetDistances({
    required double totalRouteMeters,
    required ConnectivityRiskSamplingPolicy policy,
  }) {
    final distances = <double>[];

    if (policy.includeStart) {
      distances.add(0);
    }

    var next = policy.sampleSpacingMeters;

    while (next < totalRouteMeters &&
        distances.length < policy.maximumSamples) {
      distances.add(next);
      next += policy.sampleSpacingMeters;
    }

    if (policy.includeEnd) {
      if (distances.isEmpty ||
          (distances.last - totalRouteMeters).abs() > 0.01) {
        if (distances.length >= policy.maximumSamples) {
          // Giữ điểm đầu nếu được yêu cầu, nhưng luôn ưu tiên
          // điểm cuối vì nó giúp phủ toàn tuyến.
          if (distances.isNotEmpty) {
            distances[distances.length - 1] = totalRouteMeters;
          } else {
            distances.add(totalRouteMeters);
          }
        } else {
          distances.add(totalRouteMeters);
        }
      }
    }

    if (distances.length > policy.maximumSamples) {
      return distances.take(policy.maximumSamples).toList(growable: false);
    }

    return distances;
  }

  List<double> _buildCumulativeDistances(List<RoutePoint> routePoints) {
    final cumulative = <double>[0];

    var total = 0.0;

    for (var index = 1; index < routePoints.length; index++) {
      total += _haversineMeters(
        routePoints[index - 1].latitude,
        routePoints[index - 1].longitude,
        routePoints[index].latitude,
        routePoints[index].longitude,
      );

      cumulative.add(total);
    }

    return cumulative;
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
}
