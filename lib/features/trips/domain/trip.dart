class Trip {
  const Trip({
    required this.id,
    required this.ownerId,
    required this.vehicleId,
    required this.name,
    required this.description,
    required this.status,
    required this.plannedStartAt,
    required this.plannedEndAt,
    required this.startName,
    required this.startAddress,
    required this.destinationName,
    required this.destinationAddress,
    required this.routeDistanceM,
    required this.routeDurationS,
    required this.estimatedFuelL,
    required this.estimatedMinCost,
    required this.budgetTotal,
    required this.currency,
    required this.offlineReady,
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

  final String? destinationName;
  final String? destinationAddress;

  final double? routeDistanceM;
  final int? routeDurationS;

  final double? estimatedFuelL;
  final double? estimatedMinCost;
  final double? budgetTotal;

  final String currency;

  final bool offlineReady;

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      vehicleId: map['vehicle_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      status: map['status'] as String? ?? 'draft',
      plannedStartAt: map['planned_start_at'] == null
          ? null
          : DateTime.parse(map['planned_start_at'] as String),
      plannedEndAt: map['planned_end_at'] == null
          ? null
          : DateTime.parse(map['planned_end_at'] as String),
      startName: map['start_name'] as String?,
      startAddress: map['start_address'] as String?,
      destinationName: map['destination_name'] as String?,
      destinationAddress: map['destination_address'] as String?,
      routeDistanceM: (map['route_distance_m'] as num?)?.toDouble(),
      routeDurationS: (map['route_duration_s'] as num?)?.toInt(),
      estimatedFuelL: (map['estimated_fuel_l'] as num?)?.toDouble(),
      estimatedMinCost: (map['estimated_min_cost'] as num?)?.toDouble(),
      budgetTotal: (map['budget_total'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'VND',
      offlineReady: map['offline_ready'] as bool? ?? false,
    );
  }
}
