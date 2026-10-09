class RoutePoint {
  const RoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class RouteResult {
  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });

  final int distanceMeters;
  final int durationSeconds;

  final List<RoutePoint> points;
}
