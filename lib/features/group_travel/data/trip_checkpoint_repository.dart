import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/trip_checkpoint.dart';
import '../domain/trip_checkpoint_arrival.dart';
import '../domain/trip_checkpoint_inputs.dart';

abstract interface class TripCheckpointRepository {
  Future<List<TripCheckpoint>> getCheckpoints(String tripId);
  Future<TripCheckpoint> createCheckpoint(CreateTripCheckpointInput input);
  Future<TripCheckpoint> updateCheckpoint({
    required String checkpointId,
    required UpdateTripCheckpointInput input,
  });
  Future<void> deleteCheckpoint(String checkpointId);
  Future<List<TripCheckpointArrival>> getArrivals(String tripId);
  Future<TripCheckpointArrival> confirmMyArrival(String checkpointId);
}

class SupabaseTripCheckpointRepository implements TripCheckpointRepository {
  SupabaseTripCheckpointRepository(this._client);

  final SupabaseClient _client;

  static const _checkpointColumns =
      'id, trip_id, created_by, name, note, latitude, longitude, '
      'radius_m, sort_order, planned_at, is_required, auto_arrival_enabled, '
      'created_at, updated_at';

  static const _arrivalColumns =
      'checkpoint_id, user_id, arrived_at, arrival_method, '
      'distance_m, gps_accuracy_m';

  @override
  Future<List<TripCheckpoint>> getCheckpoints(String tripId) async {
    _requireAuth();
    final rows = await _client
        .from('trip_checkpoints')
        .select(_checkpointColumns)
        .eq('trip_id', _nonEmpty(tripId, 'tripId'))
        .order('sort_order')
        .order('created_at');
    return List<TripCheckpoint>.unmodifiable(
      rows.map(
        (row) => TripCheckpoint.fromJson(Map<String, dynamic>.from(row)),
      ),
    );
  }

  @override
  Future<TripCheckpoint> createCheckpoint(
    CreateTripCheckpointInput input,
  ) async {
    _requireAuth();
    final row = await _client
        .from('trip_checkpoints')
        .insert(input.toInsertJson())
        .select(_checkpointColumns)
        .single();
    return TripCheckpoint.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<TripCheckpoint> updateCheckpoint({
    required String checkpointId,
    required UpdateTripCheckpointInput input,
  }) async {
    _requireAuth();
    final row = await _client
        .from('trip_checkpoints')
        .update(input.toUpdateJson())
        .eq('id', _nonEmpty(checkpointId, 'checkpointId'))
        .select(_checkpointColumns)
        .single();
    return TripCheckpoint.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> deleteCheckpoint(String checkpointId) async {
    _requireAuth();
    await _client
        .from('trip_checkpoints')
        .delete()
        .eq('id', _nonEmpty(checkpointId, 'checkpointId'));
  }

  @override
  Future<List<TripCheckpointArrival>> getArrivals(String tripId) async {
    _requireAuth();
    // The checkpoint table has active-member RLS. Fetch visible IDs first,
    // then query arrival rows with the DB's independent RLS enforcement.
    final checkpointRows = await _client
        .from('trip_checkpoints')
        .select('id')
        .eq('trip_id', _nonEmpty(tripId, 'tripId'));
    final ids = checkpointRows.map((row) => row['id'] as String).toList();
    if (ids.isEmpty) return const <TripCheckpointArrival>[];

    final rows = await _client
        .from('trip_checkpoint_arrivals')
        .select(_arrivalColumns)
        .inFilter('checkpoint_id', ids)
        .order('arrived_at');

    return List<TripCheckpointArrival>.unmodifiable(
      rows.map(
        (row) => TripCheckpointArrival.fromJson(Map<String, dynamic>.from(row)),
      ),
    );
  }

  @override
  Future<TripCheckpointArrival> confirmMyArrival(String checkpointId) async {
    final userId = _requireAuth();
    // 09.7A accepts manual self-attendance. Never send method='gps' from
    // a client: the validated server-side GPS RPC is reserved for 09.7D.
    final row = await _client
        .from('trip_checkpoint_arrivals')
        .insert({
          'checkpoint_id': _nonEmpty(checkpointId, 'checkpointId'),
          'user_id': userId,
          'arrival_method': 'manual',
        })
        .select(_arrivalColumns)
        .single();
    return TripCheckpointArrival.fromJson(Map<String, dynamic>.from(row));
  }

  String _requireAuth() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Người dùng chưa đăng nhập.');
    return id;
  }

  String _nonEmpty(String value, String field) {
    final result = value.trim();
    if (result.isEmpty) {
      throw ArgumentError.value(value, field, 'Không được rỗng.');
    }
    return result;
  }
}
