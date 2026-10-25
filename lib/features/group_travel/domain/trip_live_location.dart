class TripLiveLocation {
  const TripLiveLocation({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.updatedAt,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
  });

  static const Duration defaultFreshnessWindow = Duration(minutes: 2);

  final String id;
  final String tripId;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
  final double? headingDegrees;
  final DateTime recordedAt;
  final DateTime updatedAt;

  Duration ageAt(DateTime now) {
    final normalizedNow = now.toUtc();

    if (normalizedNow.isBefore(recordedAt)) {
      return Duration.zero;
    }

    return normalizedNow.difference(recordedAt);
  }

  bool isFreshAt(
    DateTime now, {
    Duration freshnessWindow = defaultFreshnessWindow,
  }) {
    if (freshnessWindow.isNegative) {
      throw ArgumentError.value(
        freshnessWindow,
        'freshnessWindow',
        'freshnessWindow không được âm.',
      );
    }

    return ageAt(now) <= freshnessWindow;
  }

  bool isStaleAt(
    DateTime now, {
    Duration freshnessWindow = defaultFreshnessWindow,
  }) {
    return !isFreshAt(now, freshnessWindow: freshnessWindow);
  }

  factory TripLiveLocation.fromJson(Map<String, dynamic> json) {
    final latitude = _requiredDouble(json['latitude'], 'latitude');

    final longitude = _requiredDouble(json['longitude'], 'longitude');

    if (latitude < -90 || latitude > 90) {
      throw const FormatException('latitude phải nằm trong [-90, 90].');
    }

    if (longitude < -180 || longitude > 180) {
      throw const FormatException('longitude phải nằm trong [-180, 180].');
    }

    final accuracyMeters = _optionalNonNegativeDouble(
      json['accuracy_m'],
      'accuracy_m',
    );

    final speedMetersPerSecond = _optionalNonNegativeDouble(
      json['speed_mps'],
      'speed_mps',
    );

    final headingDegrees = _optionalDouble(json['heading_deg'], 'heading_deg');

    if (headingDegrees != null &&
        (headingDegrees < 0 || headingDegrees >= 360)) {
      throw const FormatException('heading_deg phải nằm trong [0, 360).');
    }

    return TripLiveLocation(
      id: _requiredString(json['id'], 'id'),
      tripId: _requiredString(json['trip_id'], 'trip_id'),
      userId: _requiredString(json['user_id'], 'user_id'),
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      speedMetersPerSecond: speedMetersPerSecond,
      headingDegrees: headingDegrees,
      recordedAt: _requiredDateTime(json['recorded_at'], 'recorded_at'),
      updatedAt: _requiredDateTime(json['updated_at'], 'updated_at'),
    );
  }
}

class TripLiveLocationUpdate {
  const TripLiveLocationUpdate({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
  });

  final String tripId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
  final double? headingDegrees;
  final DateTime recordedAt;

  bool get isValid {
    return tripId.trim().isNotEmpty &&
        latitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude.isFinite &&
        longitude >= -180 &&
        longitude <= 180 &&
        (accuracyMeters == null ||
            (accuracyMeters!.isFinite && accuracyMeters! >= 0)) &&
        (speedMetersPerSecond == null ||
            (speedMetersPerSecond!.isFinite && speedMetersPerSecond! >= 0)) &&
        (headingDegrees == null ||
            (headingDegrees!.isFinite &&
                headingDegrees! >= 0 &&
                headingDegrees! < 360));
  }

  Map<String, dynamic> toRpcParams() {
    if (!isValid) {
      throw StateError('TripLiveLocationUpdate không hợp lệ.');
    }

    return {
      'p_trip_id': tripId.trim(),
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_accuracy_m': accuracyMeters,
      'p_speed_mps': speedMetersPerSecond,
      'p_heading_deg': headingDegrees,
      'p_recorded_at': recordedAt.toUtc().toIso8601String(),
    };
  }
}

String _requiredString(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }

  return value.trim();
}

double _requiredDouble(dynamic value, String field) {
  if (value is! num) {
    throw FormatException('$field phải là số.');
  }

  final result = value.toDouble();

  if (!result.isFinite) {
    throw FormatException('$field phải là số hữu hạn.');
  }

  return result;
}

double? _optionalDouble(dynamic value, String field) {
  if (value == null) {
    return null;
  }

  return _requiredDouble(value, field);
}

double? _optionalNonNegativeDouble(dynamic value, String field) {
  final result = _optionalDouble(value, field);

  if (result != null && result < 0) {
    throw FormatException('$field không được âm.');
  }

  return result;
}

DateTime _requiredDateTime(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }

  final parsed = DateTime.tryParse(value.trim());

  if (parsed == null) {
    throw FormatException('$field không hợp lệ.');
  }

  return parsed.toUtc();
}
