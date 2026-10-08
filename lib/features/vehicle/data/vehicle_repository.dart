import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/vehicle.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return VehicleRepository(client);
});

class VehicleRepository {
  VehicleRepository(this._client);

  final SupabaseClient _client;

  String _currentUserId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated');
    }

    return user.id;
  }

  Future<List<Vehicle>> getVehicles() async {
    final userId = _currentUserId();

    final data = await _client
        .from('vehicles')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: true);

    return data.map((item) => Vehicle.fromMap(item)).toList();
  }

  Future<Vehicle> getVehicleById(String vehicleId) async {
    final userId = _currentUserId();

    final data = await _client
        .from('vehicles')
        .select()
        .eq('id', vehicleId)
        .eq('user_id', userId)
        .single();

    return Vehicle.fromMap(data);
  }

  Future<void> createVehicle({
    required String name,
    required String vehicleType,
    String? brand,
    String? model,
    String? plateNumber,
    String? fuelType,
    double? fuelTankCapacityL,
    double? consumptionLPer100Km,
    double? batteryCapacityKwh,
    required bool isDefault,
  }) async {
    final userId = _currentUserId();

    final existingVehicles = await getVehicles();

    // Phương tiện đầu tiên tự động trở thành mặc định.
    final shouldBeDefault = existingVehicles.isEmpty || isDefault;

    if (shouldBeDefault) {
      await _clearDefaultVehicle(userId);
    }

    await _client.from('vehicles').insert({
      'user_id': userId,
      'name': name,
      'vehicle_type': vehicleType,
      'brand': brand,
      'model': model,
      'plate_number': plateNumber,
      'fuel_type': fuelType,
      'fuel_tank_capacity_l': fuelTankCapacityL,
      'consumption_l_per_100km': consumptionLPer100Km,
      'battery_capacity_kwh': batteryCapacityKwh,
      'is_default': shouldBeDefault,
    });
  }

  Future<void> updateVehicle({
    required String vehicleId,
    required String name,
    required String vehicleType,
    String? brand,
    String? model,
    String? plateNumber,
    String? fuelType,
    double? fuelTankCapacityL,
    double? consumptionLPer100Km,
    double? batteryCapacityKwh,
    required bool isDefault,
  }) async {
    final userId = _currentUserId();

    if (isDefault) {
      await _clearDefaultVehicle(userId);
    }

    await _client
        .from('vehicles')
        .update({
          'name': name,
          'vehicle_type': vehicleType,
          'brand': brand,
          'model': model,
          'plate_number': plateNumber,
          'fuel_type': fuelType,
          'fuel_tank_capacity_l': fuelTankCapacityL,
          'consumption_l_per_100km': consumptionLPer100Km,
          'battery_capacity_kwh': batteryCapacityKwh,
          'is_default': isDefault,
        })
        .eq('id', vehicleId)
        .eq('user_id', userId);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final userId = _currentUserId();

    await _client
        .from('vehicles')
        .delete()
        .eq('id', vehicleId)
        .eq('user_id', userId);
  }

  Future<void> _clearDefaultVehicle(String userId) async {
    await _client
        .from('vehicles')
        .update({'is_default': false})
        .eq('user_id', userId)
        .eq('is_default', true);
  }
}
