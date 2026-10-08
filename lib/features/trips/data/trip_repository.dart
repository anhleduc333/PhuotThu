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
    String? destinationName,
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
      'destination_name': destinationName,
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
    String? startName,
    String? destinationName,
    double? budgetTotal,
  }) async {
    final userId = _currentUserId();

    await _client
        .from('trips')
        .update({
          'vehicle_id': vehicleId,
          'name': name,
          'description': description,
          'planned_start_at': plannedStartAt?.toUtc().toIso8601String(),
          'planned_end_at': plannedEndAt?.toUtc().toIso8601String(),
          'start_name': startName,
          'destination_name': destinationName,
          'budget_total': budgetTotal,
        })
        .eq('id', tripId)
        .eq('owner_id', userId);
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

  Future<void> deleteTrip(String tripId) async {
    final userId = _currentUserId();

    await _client
        .from('trips')
        .delete()
        .eq('id', tripId)
        .eq('owner_id', userId);
  }
}
