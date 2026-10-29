import 'dart:math' as math;

class TripTrackPoint {
  const TripTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.measuredAt,
  });

  final double latitude;
  final double longitude;
  final DateTime measuredAt;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'measured_at': measuredAt.toUtc().toIso8601String(),
  };

  factory TripTrackPoint.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lon = json['longitude'];
    final time = DateTime.tryParse(json['measured_at']?.toString() ?? '');
    if (lat is! num || lon is! num || time == null) {
      throw const FormatException('Dữ liệu track không hợp lệ.');
    }
    final result = TripTrackPoint(
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      measuredAt: time.toUtc(),
    );
    if (!result.isValid) {
      throw const FormatException('Tọa độ track không hợp lệ.');
    }
    return result;
  }

  double metersTo(TripTrackPoint other) {
    const r = 6371000.0;
    final dLat = (other.latitude - latitude) * math.pi / 180;
    final dLon = (other.longitude - longitude) * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(latitude * math.pi / 180) *
            math.cos(other.latitude * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }
}
