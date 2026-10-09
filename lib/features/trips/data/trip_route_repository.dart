import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/trip_route_points.dart';

final tripRouteRepositoryProvider = Provider<TripRouteRepository>((ref) {
  return TripRouteRepository(ref.watch(supabaseClientProvider));
});

class TripRouteRepository {
  TripRouteRepository(this._client);

  final SupabaseClient _client;

  Future<TripRoutePoints> getRoutePoints(String tripId) async {
    final data = await _client
        .rpc('get_trip_route_points', params: {'p_trip_id': tripId})
        .single();

    return TripRoutePoints.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> updateRouteSummary({
    required String tripId,
    required int distanceMeters,
    required int durationSeconds,
  }) async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      throw StateError('User is not authenticated');
    }

    await _client
        .from('trips')
        .update({
          'route_distance_m': distanceMeters,
          'route_duration_s': durationSeconds,
        })
        .eq('id', tripId)
        .eq('owner_id', userId);
  }
}
