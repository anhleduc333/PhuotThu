import 'package:shared_preferences/shared_preferences.dart';

import '../domain/trip_readiness_checklist_snapshot.dart';

abstract interface class TripReadinessChecklistRepository {
  Future<void> save(TripReadinessChecklistSnapshot snapshot);

  Future<TripReadinessChecklistSnapshot?> load(String tripId);

  Future<bool> exists(String tripId);

  Future<void> remove(String tripId);
}

/// Legacy/synchronous SharedPreferences implementation kept primarily
/// for deterministic unit tests.
class SharedPreferencesTripReadinessChecklistRepository
    implements TripReadinessChecklistRepository {
  SharedPreferencesTripReadinessChecklistRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _prefix = 'trip_readiness_checklist_v1:';

  String _keyForTrip(String tripId) => '$_prefix${_normalizeTripId(tripId)}';

  @override
  Future<void> save(TripReadinessChecklistSnapshot snapshot) async {
    final tripId = _normalizeTripId(snapshot.tripId);

    final saved = await _preferences.setString(
      _keyForTrip(tripId),
      snapshot.encode(),
    );

    if (!saved) {
      throw StateError('Không thể lưu trip readiness checklist.');
    }
  }

  @override
  Future<TripReadinessChecklistSnapshot?> load(String tripId) async {
    final encoded = _preferences.getString(_keyForTrip(tripId));

    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    return TripReadinessChecklistSnapshot.decode(encoded);
  }

  @override
  Future<bool> exists(String tripId) async {
    return _preferences.containsKey(_keyForTrip(tripId));
  }

  @override
  Future<void> remove(String tripId) async {
    final key = _keyForTrip(tripId);
    final removed = await _preferences.remove(key);

    if (!removed && _preferences.containsKey(key)) {
      throw StateError('Không thể xóa trip readiness checklist.');
    }
  }
}

/// Production implementation.
///
/// SharedPreferencesAsync được khởi tạo lazy để provider có thể được tạo
/// trong Flutter test VM mà không yêu cầu platform implementation ngay lập tức.
class AsyncSharedPreferencesTripReadinessChecklistRepository
    implements TripReadinessChecklistRepository {
  AsyncSharedPreferencesTripReadinessChecklistRepository();

  SharedPreferencesAsync? _preferences;

  static const String _prefix = 'trip_readiness_checklist_v1:';

  SharedPreferencesAsync get _client {
    return _preferences ??= SharedPreferencesAsync();
  }

  String _keyForTrip(String tripId) => '$_prefix${_normalizeTripId(tripId)}';

  @override
  Future<void> save(TripReadinessChecklistSnapshot snapshot) async {
    final tripId = _normalizeTripId(snapshot.tripId);

    await _client.setString(_keyForTrip(tripId), snapshot.encode());
  }

  @override
  Future<TripReadinessChecklistSnapshot?> load(String tripId) async {
    final encoded = await _client.getString(_keyForTrip(tripId));

    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    return TripReadinessChecklistSnapshot.decode(encoded);
  }

  @override
  Future<bool> exists(String tripId) {
    return _client.containsKey(_keyForTrip(tripId));
  }

  @override
  Future<void> remove(String tripId) {
    return _client.remove(_keyForTrip(tripId));
  }
}

String _normalizeTripId(String tripId) {
  final normalized = tripId.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
  }

  return normalized;
}
