enum TripCheckpointArrivalMethod { manual, gps }

extension TripCheckpointArrivalMethodX on TripCheckpointArrivalMethod {
  String get key => name;
  String get label => switch (this) {
    TripCheckpointArrivalMethod.manual => 'Xác nhận thủ công',
    TripCheckpointArrivalMethod.gps => 'Xác nhận GPS',
  };
}

TripCheckpointArrivalMethod tripCheckpointArrivalMethodFromKey(String key) {
  return switch (key.trim()) {
    'manual' => TripCheckpointArrivalMethod.manual,
    'gps' => TripCheckpointArrivalMethod.gps,
    _ => throw FormatException('arrival_method không hợp lệ: $key'),
  };
}

class TripCheckpointArrival {
  const TripCheckpointArrival({
    required this.checkpointId,
    required this.userId,
    required this.arrivedAt,
    required this.method,
    this.distanceM,
    this.gpsAccuracyM,
  });

  final String checkpointId;
  final String userId;
  final DateTime arrivedAt;
  final TripCheckpointArrivalMethod method;
  final double? distanceM;
  final double? gpsAccuracyM;

  factory TripCheckpointArrival.fromJson(Map<String, dynamic> json) {
    String requiredText(String field) {
      final value = json[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('$field không hợp lệ.');
      }
      return value.trim();
    }

    double? optionalMetric(String field) {
      final value = json[field];
      if (value == null) return null;
      if (value is! num || !value.toDouble().isFinite || value < 0) {
        throw FormatException('$field không hợp lệ.');
      }
      return value.toDouble();
    }

    final when = DateTime.tryParse(requiredText('arrived_at'));
    if (when == null) throw const FormatException('arrived_at không hợp lệ.');

    return TripCheckpointArrival(
      checkpointId: requiredText('checkpoint_id'),
      userId: requiredText('user_id'),
      arrivedAt: when.toUtc(),
      method: tripCheckpointArrivalMethodFromKey(
        requiredText('arrival_method'),
      ),
      distanceM: optionalMetric('distance_m'),
      gpsAccuracyM: optionalMetric('gps_accuracy_m'),
    );
  }

  Map<String, dynamic> toJson() => {
    'checkpoint_id': checkpointId,
    'user_id': userId,
    'arrived_at': arrivedAt.toUtc().toIso8601String(),
    'arrival_method': method.key,
    'distance_m': distanceM,
    'gps_accuracy_m': gpsAccuracyM,
  };
}
