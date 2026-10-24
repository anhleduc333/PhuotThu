import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';
import '../domain/connectivity_risk.dart';
import '../domain/offline_trip_package_snapshot.dart';

class OfflineTripPackageBuilder {
  const OfflineTripPackageBuilder();

  OfflineTripPackageSnapshot build({
    required String tripId,
    required String startName,
    required String destinationName,
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required int routeDistanceMeters,
    required int routeDurationSeconds,
    required List<RoutePoint> routePoints,
    String? vehicleId,
    DateTime? plannedStartAt,
    double? budgetTotal,
    List<AlongRoutePlace> pois = const [],
    ConnectivityRiskAssessment? connectivityAssessment,
    bool connectivityProxyOnly = true,
    DateTime? savedAt,
  }) {
    final normalizedTripId = tripId.trim();
    final normalizedStartName = startName.trim();
    final normalizedDestinationName = destinationName.trim();

    if (normalizedTripId.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    if (normalizedStartName.isEmpty || normalizedDestinationName.isEmpty) {
      throw ArgumentError('Điểm bắt đầu và điểm đến không được rỗng.');
    }

    if (!_validCoordinate(startLatitude, startLongitude) ||
        !_validCoordinate(destinationLatitude, destinationLongitude)) {
      throw ArgumentError('Tọa độ chuyến đi không hợp lệ.');
    }

    if (routeDistanceMeters <= 0 ||
        routeDurationSeconds <= 0 ||
        routePoints.length < 2) {
      throw ArgumentError(
        'Route phải có khoảng cách, thời gian và ít nhất 2 điểm.',
      );
    }

    final offlineRoutePoints = routePoints
        .where((point) => _validCoordinate(point.latitude, point.longitude))
        .map(
          (point) => OfflineRoutePointSnapshot(
            latitude: point.latitude,
            longitude: point.longitude,
          ),
        )
        .toList(growable: false);

    if (offlineRoutePoints.length < 2) {
      throw ArgumentError(
        'Route không có đủ điểm tọa độ hợp lệ để lưu offline.',
      );
    }

    final offlinePois = _buildPois(pois);
    final connectivity = _buildConnectivity(
      connectivityAssessment,
      proxyOnly: connectivityProxyOnly,
    );

    return OfflineTripPackageSnapshot(
      schemaVersion: OfflineTripPackageSnapshot.currentSchemaVersion,
      savedAt: (savedAt ?? DateTime.now()).toUtc(),
      trip: OfflineTripSnapshot(
        tripId: normalizedTripId,
        startName: normalizedStartName,
        destinationName: normalizedDestinationName,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        vehicleId: _nullableTrimmed(vehicleId),
        startAt: plannedStartAt?.toUtc(),
        budgetTotal:
            budgetTotal != null && budgetTotal.isFinite && budgetTotal >= 0
            ? budgetTotal
            : null,
      ),
      route: OfflineRouteSnapshot(
        distanceMeters: routeDistanceMeters,
        durationSeconds: routeDurationSeconds,
        points: List<OfflineRoutePointSnapshot>.unmodifiable(
          offlineRoutePoints,
        ),
      ),
      pois: List<OfflinePoiSnapshot>.unmodifiable(offlinePois),
      connectivity: connectivity,
    );
  }

  List<OfflinePoiSnapshot> _buildPois(List<AlongRoutePlace> pois) {
    final deduplicated = <String, AlongRoutePlace>{};

    for (final place in pois) {
      if (!_validCoordinate(place.latitude, place.longitude)) {
        continue;
      }

      final source = place.source.trim();
      final sourceId = place.sourceId.trim();

      if (source.isEmpty || sourceId.isEmpty) {
        continue;
      }

      final key = '${source.toLowerCase()}:$sourceId';
      final existing = deduplicated[key];

      if (existing == null) {
        deduplicated[key] = place;
        continue;
      }

      final existingDistance =
          existing.distanceFromRouteMeters ?? double.infinity;
      final candidateDistance =
          place.distanceFromRouteMeters ?? double.infinity;

      if (candidateDistance < existingDistance) {
        deduplicated[key] = place;
      }
    }

    final result = deduplicated.values
        .map(
          (place) => OfflinePoiSnapshot(
            id: place.id,
            name: place.name.trim().isEmpty
                ? _fallbackPoiName(place.type)
                : place.name.trim(),
            typeKey: _poiTypeKey(place.type),
            latitude: place.latitude,
            longitude: place.longitude,
            source: place.source.trim(),
            sourceId: place.sourceId.trim(),
            address: _nullableTrimmed(place.address),
            phone: _nullableTrimmed(place.phone),
            website: _nullableTrimmed(place.website),
            distanceFromRouteMeters: _validOptionalDistance(
              place.distanceFromRouteMeters,
            ),
          ),
        )
        .toList(growable: false);

    result.sort((a, b) {
      final first = a.distanceFromRouteMeters ?? double.infinity;
      final second = b.distanceFromRouteMeters ?? double.infinity;

      final distanceCompare = first.compareTo(second);

      if (distanceCompare != 0) {
        return distanceCompare;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  OfflineConnectivitySnapshot? _buildConnectivity(
    ConnectivityRiskAssessment? assessment, {
    required bool proxyOnly,
  }) {
    if (assessment == null || !assessment.hasRiskData) {
      return null;
    }

    return OfflineConnectivitySnapshot(
      overallRiskScore: assessment.overallRiskScore,
      overallLevelKey: assessment.overallLevel.key,
      warningRoutePercent: assessment.warningRoutePercent,
      proxyOnly: proxyOnly,
      generatedAt: assessment.generatedAt?.toUtc(),
      segments: List<OfflineConnectivitySegmentSnapshot>.unmodifiable(
        assessment.segments.map(
          (segment) => OfflineConnectivitySegmentSnapshot(
            startDistanceMeters: segment.startDistanceMeters,
            endDistanceMeters: segment.endDistanceMeters,
            levelKey: segment.level.key,
            averageRiskScore: segment.averageRiskScore,
            maxRiskScore: segment.maxRiskScore,
          ),
        ),
      ),
    );
  }

  bool _validCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  double? _validOptionalDistance(double? value) {
    if (value == null || !value.isFinite || value < 0) {
      return null;
    }

    return value;
  }

  String? _nullableTrimmed(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  String _poiTypeKey(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return 'fuel';
      case AlongRoutePlaceType.restArea:
        return 'accommodation';
      case AlongRoutePlaceType.food:
        return 'food';
      case AlongRoutePlaceType.repair:
        return 'repair';
      case AlongRoutePlaceType.medical:
        return 'medical';
    }
  }

  String _fallbackPoiName(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return 'Cây xăng';
      case AlongRoutePlaceType.restArea:
        return 'Nơi nghỉ / lưu trú';
      case AlongRoutePlaceType.food:
        return 'Ăn uống';
      case AlongRoutePlaceType.repair:
        return 'Sửa chữa';
      case AlongRoutePlaceType.medical:
        return 'Y tế';
    }
  }
}
