import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/trip_track_point.dart';

/// Local-only track. One history per authenticated user and trip.
/// Does not capture anything unless the user presses Start.
class TripTrackLocalRepository {
  TripTrackLocalRepository({SharedPreferencesAsync? preferences})
    : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  String _key(String tripId, String userId) =>
      'phuotthu_track_v1:${userId.trim()}:${tripId.trim()}';

  Future<List<TripTrackPoint>> load(String tripId, String userId) async {
    final json = await _prefs.getString(_key(tripId, userId));
    if (json == null || json.isEmpty) {
      return const [];
    }
    final values = jsonDecode(json);
    if (values is! List) {
      throw const FormatException('Định dạng track không hợp lệ.');
    }
    return List<TripTrackPoint>.unmodifiable(
      values.map(
        (value) =>
            TripTrackPoint.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Future<void> save(
    String tripId,
    String userId,
    List<TripTrackPoint> points,
  ) async {
    final records = points.take(3000).map((p) => p.toJson()).toList();
    await _prefs.setString(_key(tripId, userId), jsonEncode(records));
  }

  Future<void> remove(String tripId, String userId) =>
      _prefs.remove(_key(tripId, userId));
}
