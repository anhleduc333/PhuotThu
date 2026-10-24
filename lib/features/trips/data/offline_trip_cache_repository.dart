import 'package:shared_preferences/shared_preferences.dart';

import '../domain/offline_trip_package_snapshot.dart';

abstract interface class OfflineTripCacheRepository {
  Future<void> save(OfflineTripPackageSnapshot snapshot);

  Future<OfflineTripPackageSnapshot?> load(String tripId);

  Future<bool> exists(String tripId);

  Future<void> remove(String tripId);

  Future<void> clearAll();

  Future<List<String>> cachedTripIds();
}

/// Legacy implementation retained for unit tests/backward compatibility.
class SharedPreferencesOfflineTripCacheRepository
    implements OfflineTripCacheRepository {
  SharedPreferencesOfflineTripCacheRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String _packagePrefix = 'offline_trip_package_v1:';
  static const String _indexKey = 'offline_trip_package_v1:index';

  String _keyForTrip(String tripId) {
    final normalized = _normalizeTripId(tripId);
    return '$_packagePrefix$normalized';
  }

  @override
  Future<void> save(OfflineTripPackageSnapshot snapshot) async {
    final tripId = _normalizeTripId(snapshot.trip.tripId);

    final packageSaved = await _preferences.setString(
      _keyForTrip(tripId),
      snapshot.encode(),
    );

    if (!packageSaved) {
      throw StateError('Không thể lưu offline package.');
    }

    final ids = {..._preferences.getStringList(_indexKey) ?? const <String>[]}
      ..add(tripId);

    final indexSaved = await _preferences.setStringList(
      _indexKey,
      ids.toList(growable: false)..sort(),
    );

    if (!indexSaved) {
      throw StateError('Không thể cập nhật offline package index.');
    }
  }

  @override
  Future<OfflineTripPackageSnapshot?> load(String tripId) async {
    final encoded = _preferences.getString(_keyForTrip(tripId));

    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    return OfflineTripPackageSnapshot.decode(encoded);
  }

  @override
  Future<bool> exists(String tripId) async {
    return _preferences.containsKey(_keyForTrip(tripId));
  }

  @override
  Future<void> remove(String tripId) async {
    final normalized = _normalizeTripId(tripId);
    final removed = await _preferences.remove(_keyForTrip(normalized));

    if (!removed && _preferences.containsKey(_keyForTrip(normalized))) {
      throw StateError('Không thể xóa offline package.');
    }

    final ids = {..._preferences.getStringList(_indexKey) ?? const <String>[]}
      ..remove(normalized);

    final indexSaved = await _preferences.setStringList(
      _indexKey,
      ids.toList(growable: false)..sort(),
    );

    if (!indexSaved) {
      throw StateError('Không thể cập nhật offline package index.');
    }
  }

  @override
  Future<void> clearAll() async {
    final ids = await cachedTripIds();

    for (final tripId in ids) {
      await _preferences.remove(_keyForTrip(tripId));
    }

    final removed = await _preferences.remove(_indexKey);

    if (!removed && _preferences.containsKey(_indexKey)) {
      throw StateError('Không thể xóa offline package index.');
    }
  }

  @override
  Future<List<String>> cachedTripIds() async {
    final ids = _preferences.getStringList(_indexKey) ?? const <String>[];

    return _normalizeIds(ids);
  }
}

/// Production implementation.
///
/// SharedPreferencesAsync is created lazily on the first real cache operation.
/// This keeps Riverpod provider construction platform-agnostic and makes
/// provider wiring testable in the Dart/Flutter test VM, where plugin platform
/// implementations are not registered automatically.
class AsyncSharedPreferencesOfflineTripCacheRepository
    implements OfflineTripCacheRepository {
  AsyncSharedPreferencesOfflineTripCacheRepository();

  SharedPreferencesAsync? _preferences;

  static const String _packagePrefix = 'offline_trip_package_v1:';
  static const String _indexKey = 'offline_trip_package_v1:index';

  SharedPreferencesAsync get _client {
    return _preferences ??= SharedPreferencesAsync();
  }

  String _keyForTrip(String tripId) {
    final normalized = _normalizeTripId(tripId);
    return '$_packagePrefix$normalized';
  }

  @override
  Future<void> save(OfflineTripPackageSnapshot snapshot) async {
    final tripId = _normalizeTripId(snapshot.trip.tripId);
    final preferences = _client;

    await preferences.setString(_keyForTrip(tripId), snapshot.encode());

    final currentIds =
        await preferences.getStringList(_indexKey) ?? const <String>[];

    final ids = {...currentIds}..add(tripId);

    await preferences.setStringList(
      _indexKey,
      ids.toList(growable: false)..sort(),
    );
  }

  @override
  Future<OfflineTripPackageSnapshot?> load(String tripId) async {
    final encoded = await _client.getString(_keyForTrip(tripId));

    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    return OfflineTripPackageSnapshot.decode(encoded);
  }

  @override
  Future<bool> exists(String tripId) {
    return _client.containsKey(_keyForTrip(tripId));
  }

  @override
  Future<void> remove(String tripId) async {
    final normalized = _normalizeTripId(tripId);
    final preferences = _client;

    await preferences.remove(_keyForTrip(normalized));

    final currentIds =
        await preferences.getStringList(_indexKey) ?? const <String>[];

    final ids = {...currentIds}..remove(normalized);

    await preferences.setStringList(
      _indexKey,
      ids.toList(growable: false)..sort(),
    );
  }

  @override
  Future<void> clearAll() async {
    final preferences = _client;
    final ids = await cachedTripIds();

    for (final tripId in ids) {
      await preferences.remove(_keyForTrip(tripId));
    }

    await preferences.remove(_indexKey);
  }

  @override
  Future<List<String>> cachedTripIds() async {
    final ids = await _client.getStringList(_indexKey) ?? const <String>[];

    return _normalizeIds(ids);
  }
}

String _normalizeTripId(String tripId) {
  final normalized = tripId.trim();

  if (normalized.isEmpty) {
    throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
  }

  return normalized;
}

List<String> _normalizeIds(Iterable<String> ids) {
  final normalized =
      ids
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();

  return List<String>.unmodifiable(normalized);
}
