import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/place_result.dart';
import 'place_search_service.dart';

class NominatimPlaceSearchService implements PlaceSearchService {
  NominatimPlaceSearchService(this._client);

  final http.Client _client;

  DateTime? _lastRequestAt;

  static const Duration _minimumRequestInterval = Duration(milliseconds: 1100);

  @override
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 2) {
      return const [];
    }

    await _respectRateLimit();

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': normalizedQuery,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'namedetails': '1',
      'accept-language': 'vi',
    });

    _lastRequestAt = DateTime.now();

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'PhuotThu/0.1 (com.anhleduc333.phuotthu)',
        'Accept': 'application/json',
        'Accept-Language': 'vi,en;q=0.8',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Nominatim HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! List) {
      throw const FormatException('Invalid Nominatim response');
    }

    return decoded.map<PlaceResult>((item) {
      if (item is! Map) {
        throw const FormatException('Invalid place result');
      }

      return PlaceResult.fromNominatimMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<void> _respectRateLimit() async {
    final previous = _lastRequestAt;

    if (previous == null) {
      return;
    }

    final elapsed = DateTime.now().difference(previous);

    if (elapsed >= _minimumRequestInterval) {
      return;
    }

    await Future<void>.delayed(_minimumRequestInterval - elapsed);
  }
}
