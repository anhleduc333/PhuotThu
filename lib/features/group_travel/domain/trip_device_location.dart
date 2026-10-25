class TripDeviceLocation {
  const TripDeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.measuredAt,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;
  final double? headingDegrees;
  final DateTime measuredAt;

  bool get isValid {
    return latitude.isFinite &&
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

  TripDeviceLocation normalized() {
    if (!isValid) {
      throw StateError('TripDeviceLocation không hợp lệ.');
    }

    return TripDeviceLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      speedMetersPerSecond: speedMetersPerSecond,
      headingDegrees: headingDegrees,
      measuredAt: measuredAt.toUtc(),
    );
  }
}
