import 'package:geolocator/geolocator.dart';

import '../domain/trip_device_location.dart';
import 'trip_location_source.dart';

class GeolocatorTripLocationSource implements TripLocationSource {
  const GeolocatorTripLocationSource({
    this.locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  });

  final LocationSettings locationSettings;

  @override
  Future<TripLocationAccessResult> ensureAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return const TripLocationAccessResult(
        status: TripLocationAccessStatus.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return const TripLocationAccessResult(
          status: TripLocationAccessStatus.ready,
        );

      case LocationPermission.deniedForever:
        return const TripLocationAccessResult(
          status: TripLocationAccessStatus.permissionDeniedForever,
        );

      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return const TripLocationAccessResult(
          status: TripLocationAccessStatus.permissionDenied,
        );
    }
  }

  @override
  Stream<TripDeviceLocation> watchLocations() {
    return Geolocator.getPositionStream(locationSettings: locationSettings)
        .map(_fromPosition);
  }

  TripDeviceLocation _fromPosition(Position position) {
    final accuracy = _nonNegativeOrNull(position.accuracy);

    final speed = _nonNegativeOrNull(position.speed);

    final heading = _headingOrNull(position.heading);

    return TripDeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: accuracy,
      speedMetersPerSecond: speed,
      headingDegrees: heading,
      measuredAt: position.timestamp.toUtc(),
    );
  }

  double? _nonNegativeOrNull(double value) {
    if (!value.isFinite || value < 0) {
      return null;
    }

    return value;
  }

  double? _headingOrNull(double value) {
    if (!value.isFinite || value < 0 || value >= 360) {
      return null;
    }

    return value;
  }
}
