import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/trip_live_location.dart';

abstract interface class TripLiveLocationRepository {
  Stream<List<TripLiveLocation>> watchTripLocations(String tripId);

  Future<void> publishMyLocation(TripLiveLocationUpdate update);

  Future<void> clearMyLocation(String tripId);
}

class SupabaseTripLiveLocationRepository implements TripLiveLocationRepository {
  SupabaseTripLiveLocationRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<TripLiveLocation>> watchTripLocations(String tripId) {
    final normalizedTripId = _normalizeTripId(tripId);

    _requireAuthenticatedUser();

    return _client
        .from('trip_live_locations')
        .stream(primaryKey: ['id'])
        .eq('trip_id', normalizedTripId)
        .order('recorded_at')
        .map(
          (rows) => List<TripLiveLocation>.unmodifiable(
            rows.map(
              (row) =>
                  TripLiveLocation.fromJson(Map<String, dynamic>.from(row)),
            ),
          ),
        );
  }

  @override
  Future<void> publishMyLocation(TripLiveLocationUpdate update) async {
    _requireAuthenticatedUser();

    if (!update.isValid) {
      throw ArgumentError.value(
        update,
        'update',
        'Dữ liệu vị trí không hợp lệ.',
      );
    }

    await _client.rpc(
      'publish_my_trip_live_location',
      params: update.toRpcParams(),
    );
  }

  @override
  Future<void> clearMyLocation(String tripId) async {
    final normalizedTripId = _normalizeTripId(tripId);

    _requireAuthenticatedUser();

    await _client.rpc(
      'clear_my_trip_live_location',
      params: {'p_trip_id': normalizedTripId},
    );
  }

  String _requireAuthenticatedUser() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Người dùng chưa đăng nhập.');
    }

    return user.id;
  }

  String _normalizeTripId(String tripId) {
    final normalized = tripId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    return normalized;
  }
}
