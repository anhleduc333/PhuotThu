import 'dart:convert';

class OfflineTripSnapshot {
  const OfflineTripSnapshot({
    required this.tripId,
    required this.startName,
    required this.destinationName,
    required this.startLatitude,
    required this.startLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.vehicleId,
    this.startAt,
    this.budgetTotal,
  });

  final String tripId;
  final String startName;
  final String destinationName;
  final double startLatitude;
  final double startLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String? vehicleId;
  final DateTime? startAt;
  final double? budgetTotal;

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'start_name': startName,
      'destination_name': destinationName,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'vehicle_id': vehicleId,
      'start_at': startAt?.toUtc().toIso8601String(),
      'budget_total': budgetTotal,
    };
  }

  factory OfflineTripSnapshot.fromJson(Map<String, dynamic> json) {
    return OfflineTripSnapshot(
      tripId: _requiredString(json, 'trip_id'),
      startName: _requiredString(json, 'start_name'),
      destinationName: _requiredString(json, 'destination_name'),
      startLatitude: _requiredDouble(json, 'start_latitude'),
      startLongitude: _requiredDouble(json, 'start_longitude'),
      destinationLatitude: _requiredDouble(json, 'destination_latitude'),
      destinationLongitude: _requiredDouble(json, 'destination_longitude'),
      vehicleId: _optionalString(json['vehicle_id']),
      startAt: _optionalDateTime(json['start_at']),
      budgetTotal: _optionalDouble(json['budget_total']),
    );
  }
}

class OfflineRoutePointSnapshot {
  const OfflineRoutePointSnapshot({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory OfflineRoutePointSnapshot.fromJson(Map<String, dynamic> json) {
    return OfflineRoutePointSnapshot(
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
    );
  }
}

class OfflineRouteSnapshot {
  const OfflineRouteSnapshot({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final int distanceMeters;
  final int durationSeconds;
  final List<OfflineRoutePointSnapshot> points;

  Map<String, dynamic> toJson() {
    return {
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'points': points.map((point) => point.toJson()).toList(growable: false),
    };
  }

  factory OfflineRouteSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];

    if (rawPoints is! List) {
      throw const FormatException('Offline route points không hợp lệ.');
    }

    return OfflineRouteSnapshot(
      distanceMeters: _requiredInt(json, 'distance_meters'),
      durationSeconds: _requiredInt(json, 'duration_seconds'),
      points: List<OfflineRoutePointSnapshot>.unmodifiable(
        rawPoints.map(
          (item) => OfflineRoutePointSnapshot.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }
}

class OfflinePoiSnapshot {
  const OfflinePoiSnapshot({
    required this.id,
    required this.name,
    required this.typeKey,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.sourceId,
    this.address,
    this.phone,
    this.website,
    this.distanceFromRouteMeters,
  });

  final String id;
  final String name;
  final String typeKey;
  final double latitude;
  final double longitude;
  final String source;
  final String sourceId;
  final String? address;
  final String? phone;
  final String? website;
  final double? distanceFromRouteMeters;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type_key': typeKey,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
      'source_id': sourceId,
      'address': address,
      'phone': phone,
      'website': website,
      'distance_from_route_meters': distanceFromRouteMeters,
    };
  }

  factory OfflinePoiSnapshot.fromJson(Map<String, dynamic> json) {
    return OfflinePoiSnapshot(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      typeKey: _requiredString(json, 'type_key'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      source: _requiredString(json, 'source'),
      sourceId: _requiredString(json, 'source_id'),
      address: _optionalString(json['address']),
      phone: _optionalString(json['phone']),
      website: _optionalString(json['website']),
      distanceFromRouteMeters: _optionalDouble(
        json['distance_from_route_meters'],
      ),
    );
  }
}

class OfflineConnectivitySegmentSnapshot {
  const OfflineConnectivitySegmentSnapshot({
    required this.startDistanceMeters,
    required this.endDistanceMeters,
    required this.levelKey,
    required this.averageRiskScore,
    required this.maxRiskScore,
  });

  final double startDistanceMeters;
  final double endDistanceMeters;
  final String levelKey;
  final double averageRiskScore;
  final double maxRiskScore;

  Map<String, dynamic> toJson() {
    return {
      'start_distance_meters': startDistanceMeters,
      'end_distance_meters': endDistanceMeters,
      'level_key': levelKey,
      'average_risk_score': averageRiskScore,
      'max_risk_score': maxRiskScore,
    };
  }

  factory OfflineConnectivitySegmentSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    return OfflineConnectivitySegmentSnapshot(
      startDistanceMeters: _requiredDouble(json, 'start_distance_meters'),
      endDistanceMeters: _requiredDouble(json, 'end_distance_meters'),
      levelKey: _requiredString(json, 'level_key'),
      averageRiskScore: _requiredDouble(json, 'average_risk_score'),
      maxRiskScore: _requiredDouble(json, 'max_risk_score'),
    );
  }
}

class OfflineConnectivitySnapshot {
  const OfflineConnectivitySnapshot({
    required this.overallRiskScore,
    required this.overallLevelKey,
    required this.warningRoutePercent,
    required this.proxyOnly,
    required this.segments,
    this.generatedAt,
  });

  final double overallRiskScore;
  final String overallLevelKey;
  final double warningRoutePercent;
  final bool proxyOnly;
  final List<OfflineConnectivitySegmentSnapshot> segments;
  final DateTime? generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'overall_risk_score': overallRiskScore,
      'overall_level_key': overallLevelKey,
      'warning_route_percent': warningRoutePercent,
      'proxy_only': proxyOnly,
      'generated_at': generatedAt?.toUtc().toIso8601String(),
      'segments': segments
          .map((segment) => segment.toJson())
          .toList(growable: false),
    };
  }

  factory OfflineConnectivitySnapshot.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];

    if (rawSegments is! List) {
      throw const FormatException(
        'Offline connectivity segments không hợp lệ.',
      );
    }

    return OfflineConnectivitySnapshot(
      overallRiskScore: _requiredDouble(json, 'overall_risk_score'),
      overallLevelKey: _requiredString(json, 'overall_level_key'),
      warningRoutePercent: _requiredDouble(json, 'warning_route_percent'),
      proxyOnly: _requiredBool(json, 'proxy_only'),
      generatedAt: _optionalDateTime(json['generated_at']),
      segments: List<OfflineConnectivitySegmentSnapshot>.unmodifiable(
        rawSegments.map(
          (item) => OfflineConnectivitySegmentSnapshot.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }
}

class OfflineTripPackageSnapshot {
  const OfflineTripPackageSnapshot({
    required this.schemaVersion,
    required this.savedAt,
    required this.trip,
    required this.route,
    required this.pois,
    this.connectivity,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime savedAt;
  final OfflineTripSnapshot trip;
  final OfflineRouteSnapshot route;
  final List<OfflinePoiSnapshot> pois;
  final OfflineConnectivitySnapshot? connectivity;

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'saved_at': savedAt.toUtc().toIso8601String(),
      'trip': trip.toJson(),
      'route': route.toJson(),
      'pois': pois.map((poi) => poi.toJson()).toList(growable: false),
      'connectivity': connectivity?.toJson(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory OfflineTripPackageSnapshot.decode(String encoded) {
    final decoded = jsonDecode(encoded);

    if (decoded is! Map) {
      throw const FormatException('Offline package JSON không hợp lệ.');
    }

    return OfflineTripPackageSnapshot.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  factory OfflineTripPackageSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');

    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Offline package schema $schemaVersion chưa được hỗ trợ.',
      );
    }

    final tripJson = json['trip'];
    final routeJson = json['route'];
    final rawPois = json['pois'];
    final connectivityJson = json['connectivity'];

    if (tripJson is! Map || routeJson is! Map || rawPois is! List) {
      throw const FormatException('Offline package thiếu dữ liệu bắt buộc.');
    }

    return OfflineTripPackageSnapshot(
      schemaVersion: schemaVersion,
      savedAt: _requiredDateTime(json, 'saved_at'),
      trip: OfflineTripSnapshot.fromJson(Map<String, dynamic>.from(tripJson)),
      route: OfflineRouteSnapshot.fromJson(
        Map<String, dynamic>.from(routeJson),
      ),
      pois: List<OfflinePoiSnapshot>.unmodifiable(
        rawPois.map(
          (item) => OfflinePoiSnapshot.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      connectivity: connectivityJson is Map
          ? OfflineConnectivitySnapshot.fromJson(
              Map<String, dynamic>.from(connectivityJson),
            )
          : null,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);

  if (value == null) {
    throw FormatException('Thiếu hoặc sai trường "$key".');
  }

  return value;
}

String? _optionalString(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw const FormatException('Giá trị string không hợp lệ.');
  }

  final trimmed = value.trim();

  return trimmed.isEmpty ? null : trimmed;
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _optionalDouble(json[key]);

  if (value == null || !value.isFinite) {
    throw FormatException('Thiếu hoặc sai trường "$key".');
  }

  return value;
}

double? _optionalDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  throw const FormatException('Giá trị số không hợp lệ.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is int) {
    return value;
  }

  if (value is num && value == value.roundToDouble()) {
    return value.toInt();
  }

  throw FormatException('Thiếu hoặc sai trường "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is bool) {
    return value;
  }

  throw FormatException('Thiếu hoặc sai trường "$key".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _optionalDateTime(json[key]);

  if (value == null) {
    throw FormatException('Thiếu hoặc sai trường "$key".');
  }

  return value;
}

DateTime? _optionalDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw const FormatException('Giá trị DateTime không hợp lệ.');
  }

  return DateTime.tryParse(value)?.toUtc();
}
