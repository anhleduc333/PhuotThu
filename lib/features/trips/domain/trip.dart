class Trip {
  const Trip({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.status,
    required this.currency,
    required this.offlineReady,
    this.vehicleId,
    this.description,
    this.plannedStartAt,
    this.plannedEndAt,
    this.startName,
    this.startAddress,
    this.startPlaceId,
    this.destinationName,
    this.destinationAddress,
    this.destinationPlaceId,
    this.routeDistanceM,
    this.routeDurationS,
    this.estimatedFuelL,
    this.estimatedMinCost,
    this.budgetTotal,
  });

  final String id;
  final String ownerId;
  final String? vehicleId;

  final String name;
  final String? description;
  final String status;

  final DateTime? plannedStartAt;
  final DateTime? plannedEndAt;

  final String? startName;
  final String? startAddress;
  final String? startPlaceId;

  final String? destinationName;
  final String? destinationAddress;
  final String? destinationPlaceId;

  final int? routeDistanceM;
  final int? routeDurationS;

  final double? estimatedFuelL;
  final double? estimatedMinCost;
  final double? budgetTotal;

  final String currency;
  final bool offlineReady;

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'].toString(),
      ownerId: map['owner_id'].toString(),
      vehicleId: map['vehicle_id']?.toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      status: map['status']?.toString() ?? 'draft',
      plannedStartAt: _parseDateTime(map['planned_start_at']),
      plannedEndAt: _parseDateTime(map['planned_end_at']),
      startName: map['start_name']?.toString(),
      startAddress: map['start_address']?.toString(),
      startPlaceId: map['start_place_id']?.toString(),
      destinationName: map['destination_name']?.toString(),
      destinationAddress: map['destination_address']?.toString(),
      destinationPlaceId: map['destination_place_id']?.toString(),
      routeDistanceM: _parseInt(map['route_distance_m']),
      routeDurationS: _parseInt(map['route_duration_s']),
      estimatedFuelL: _parseDouble(map['estimated_fuel_l']),
      estimatedMinCost: _parseDouble(map['estimated_min_cost']),
      budgetTotal: _parseDouble(map['budget_total']),
      currency: map['currency']?.toString() ?? 'VND',
      offlineReady: map['offline_ready'] == true,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}
