class Vehicle {
  const Vehicle({
    required this.id,
    required this.userId,
    required this.name,
    required this.vehicleType,
    required this.brand,
    required this.model,
    required this.plateNumber,
    required this.fuelType,
    required this.fuelTankCapacityL,
    required this.consumptionLPer100Km,
    required this.batteryCapacityKwh,
    required this.isDefault,
  });

  final String id;
  final String userId;

  final String name;
  final String vehicleType;

  final String? brand;
  final String? model;
  final String? plateNumber;

  final String? fuelType;

  final double? fuelTankCapacityL;

  final double? consumptionLPer100Km;

  final double? batteryCapacityKwh;

  final bool isDefault;

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      vehicleType: map['vehicle_type'] as String,
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      plateNumber: map['plate_number'] as String?,
      fuelType: map['fuel_type'] as String?,
      fuelTankCapacityL: (map['fuel_tank_capacity_l'] as num?)?.toDouble(),
      consumptionLPer100Km: (map['consumption_l_per_100km'] as num?)
          ?.toDouble(),
      batteryCapacityKwh: (map['battery_capacity_kwh'] as num?)?.toDouble(),
      isDefault: map['is_default'] as bool? ?? false,
    );
  }
}
