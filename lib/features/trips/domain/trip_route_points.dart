class TripRoutePoints {
  const TripRoutePoints({
    required this.tripId,
    required this.startLatitude,
    required this.startLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final String tripId;

  final double startLatitude;
  final double startLongitude;

  final double destinationLatitude;
  final double destinationLongitude;

  factory TripRoutePoints.fromMap(Map<String, dynamic> map) {
    return TripRoutePoints(
      tripId: map['trip_id'].toString(),
      startLatitude: _requiredDouble(map['start_lat'], 'start_lat'),
      startLongitude: _requiredDouble(map['start_lng'], 'start_lng'),
      destinationLatitude: _requiredDouble(
        map['destination_lat'],
        'destination_lat',
      ),
      destinationLongitude: _requiredDouble(
        map['destination_lng'],
        'destination_lng',
      ),
    );
  }

  static double _requiredDouble(dynamic value, String field) {
    if (value == null) {
      throw StateError('Missing route coordinate: $field');
    }

    if (value is num) {
      return value.toDouble();
    }

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      throw StateError('Invalid route coordinate: $field');
    }

    return parsed;
  }
}
