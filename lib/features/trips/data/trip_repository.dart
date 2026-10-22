import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/trip.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(supabaseClientProvider));
});

class TripRepository {
  TripRepository(this._client);

  final SupabaseClient _client;

  String _currentUserId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('User is not authenticated');
    }

    return user.id;
  }

  String? _geographyPoint({
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude == null || longitude == null) {
      return null;
    }

    // PostGIS POINT sử dụng thứ tự:
    // longitude latitude
    return 'SRID=4326;POINT($longitude $latitude)';
  }

  Future<List<Trip>> getTrips() async {
    final userId = _currentUserId();

    final data = await _client
        .from('trips')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return data.map((item) => Trip.fromMap(item)).toList();
  }

  Future<Trip> getTripById(String tripId) async {
    final userId = _currentUserId();

    final data = await _client
        .from('trips')
        .select()
        .eq('id', tripId)
        .eq('owner_id', userId)
        .single();

    return Trip.fromMap(data);
  }

  Future<void> createTrip({
    required String name,
    String? description,
    String? vehicleId,
    DateTime? plannedStartAt,
    DateTime? plannedEndAt,
    String? startName,
    String? startAddress,
    String? startPlaceId,
    double? startLatitude,
    double? startLongitude,
    String? destinationName,
    String? destinationAddress,
    String? destinationPlaceId,
    double? destinationLatitude,
    double? destinationLongitude,
    double? budgetTotal,
  }) async {
    final userId = _currentUserId();

    await _client.from('trips').insert({
      'owner_id': userId,
      'vehicle_id': vehicleId,
      'name': name,
      'description': description,
      'status': 'draft',
      'planned_start_at': plannedStartAt?.toUtc().toIso8601String(),
      'planned_end_at': plannedEndAt?.toUtc().toIso8601String(),

      'start_name': startName,
      'start_address': startAddress,
      'start_place_id': startPlaceId,
      'start_location': _geographyPoint(
        latitude: startLatitude,
        longitude: startLongitude,
      ),

      'destination_name': destinationName,
      'destination_address': destinationAddress,
      'destination_place_id': destinationPlaceId,
      'destination_location': _geographyPoint(
        latitude: destinationLatitude,
        longitude: destinationLongitude,
      ),

      'budget_total': budgetTotal,
      'currency': 'VND',
    });
  }

  Future<void> updateTrip({
    required String tripId,
    required String name,
    String? description,
    String? vehicleId,
    DateTime? plannedStartAt,
    DateTime? plannedEndAt,
    double? budgetTotal,

    bool updateStartPlace = false,
    String? startName,
    String? startAddress,
    String? startPlaceId,
    double? startLatitude,
    double? startLongitude,

    bool updateDestinationPlace = false,
    String? destinationName,
    String? destinationAddress,
    String? destinationPlaceId,
    double? destinationLatitude,
    double? destinationLongitude,
  }) async {
    final userId = _currentUserId();

    final currentData = await _client
        .from('trips')
        .select('vehicle_id')
        .eq('id', tripId)
        .eq('owner_id', userId)
        .single();

    final currentVehicleId = currentData['vehicle_id']?.toString();

    final vehicleChanged = currentVehicleId != vehicleId;

    final routeChanged = updateStartPlace || updateDestinationPlace;

    final updates = <String, dynamic>{
      'vehicle_id': vehicleId,
      'name': name,
      'description': description,
      'planned_start_at': plannedStartAt?.toUtc().toIso8601String(),
      'planned_end_at': plannedEndAt?.toUtc().toIso8601String(),
      'budget_total': budgetTotal,
    };

    if (updateStartPlace) {
      updates.addAll({
        'start_name': startName,
        'start_address': startAddress,
        'start_place_id': startPlaceId,
        'start_location': _geographyPoint(
          latitude: startLatitude,
          longitude: startLongitude,
        ),
      });
    }

    if (updateDestinationPlace) {
      updates.addAll({
        'destination_name': destinationName,
        'destination_address': destinationAddress,
        'destination_place_id': destinationPlaceId,
        'destination_location': _geographyPoint(
          latitude: destinationLatitude,
          longitude: destinationLongitude,
        ),
      });
    }

    if (routeChanged) {
      // Điểm đi hoặc điểm đến thay đổi:
      // tuyến cũ không còn hợp lệ.
      updates.addAll({
        'route_distance_m': null,
        'route_duration_s': null,
        'estimated_fuel_l': null,
      });
    } else if (vehicleChanged) {
      // Chỉ đổi phương tiện:
      // tuyến vẫn đúng nhưng lượng nhiên liệu cũ
      // không còn hợp lệ.
      updates.addAll({'estimated_fuel_l': null});
    }

    await _client
        .from('trips')
        .update(updates)
        .eq('id', tripId)
        .eq('owner_id', userId);

    if (routeChanged || vehicleChanged) {
      // Chi phí nhiên liệu phụ thuộc vào tuyến đường
      // và phương tiện.
      //
      // Khi một trong hai thay đổi, phải xóa khoản
      // nhiên liệu cũ khỏi Budget Simulator.
      //
      // Trigger của trip_budget_items sẽ tự tính lại
      // trips.estimated_min_cost từ các khoản còn lại.
      await _removeFuelBudgetItem(tripId);
    }
  }

  Future<void> updateTripStatus({
    required String tripId,
    required String status,
  }) async {
    final userId = _currentUserId();

    const allowedStatuses = {
      'draft',
      'planned',
      'active',
      'completed',
      'cancelled',
    };

    if (!allowedStatuses.contains(status)) {
      throw ArgumentError('Invalid trip status: $status');
    }

    await _client
        .from('trips')
        .update({'status': status})
        .eq('id', tripId)
        .eq('owner_id', userId);
  }

  /// Cập nhật riêng lượng nhiên liệu dự kiến.
  ///
  /// Từ DEV-08D.3 trở đi, estimated_min_cost không còn
  /// được cập nhật trực tiếp tại đây vì nó là tổng các
  /// khoản chi trong trip_budget_items.
  Future<void> updateEstimatedFuel({
    required String tripId,
    required double? estimatedFuelL,
  }) async {
    final userId = _currentUserId();

    await _client
        .from('trips')
        .update({'estimated_fuel_l': estimatedFuelL})
        .eq('id', tripId)
        .eq('owner_id', userId);
  }

  /// Method cũ được giữ tạm thời để các màn hình hiện tại
  /// chưa bị lỗi trong quá trình chuyển sang Budget Simulator.
  ///
  /// Sau khi hoàn tất DEV-08D.3, code mới nên sử dụng:
  /// - updateEstimatedFuel()
  /// - trip_budget_items
  ///
  /// thay vì ghi trực tiếp estimated_min_cost.
  Future<void> updateTripEstimates({
    required String tripId,
    required double? estimatedFuelL,
    required double? estimatedMinCost,
  }) async {
    final userId = _currentUserId();

    await _client
        .from('trips')
        .update({
          'estimated_fuel_l': estimatedFuelL,
          'estimated_min_cost': estimatedMinCost,
        })
        .eq('id', tripId)
        .eq('owner_id', userId);
  }

  Future<void> _removeFuelBudgetItem(String tripId) async {
    await _client
        .from('trip_budget_items')
        .delete()
        .eq('trip_id', tripId)
        .eq('category', 'fuel');
  }

  Future<void> deleteTrip(String tripId) async {
    final userId = _currentUserId();

    await _client
        .from('trips')
        .delete()
        .eq('id', tripId)
        .eq('owner_id', userId);
  }
}
