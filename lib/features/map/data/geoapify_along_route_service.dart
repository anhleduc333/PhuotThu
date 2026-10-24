import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/along_route_place.dart';
import '../domain/along_route_result.dart';
import '../domain/route_result.dart';
import 'along_route_service.dart';

class GeoapifyAlongRouteService implements AlongRouteService {
  GeoapifyAlongRouteService(
    this._client, {
    required String apiKey,
    Uri? endpoint,
  }) : _apiKey = apiKey.trim(),
       _endpoint = endpoint ?? Uri.parse('https://api.geoapify.com/v2/places');

  final http.Client _client;
  final String _apiKey;
  final Uri _endpoint;

  static const Duration _timeout = Duration(seconds: 30);
  static const double _earthRadiusMeters = 6371000;
  static const int _maximumQueryPoints = 1500;

  @override
  Future<AlongRouteResult> search({
    required List<RoutePoint> routePoints,
    Set<AlongRoutePlaceType> types = const {
      AlongRoutePlaceType.fuel,
      AlongRoutePlaceType.restArea,
      AlongRoutePlaceType.food,
      AlongRoutePlaceType.repair,
      AlongRoutePlaceType.medical,
    },
    double searchRadiusMeters = 3000,
    int maxResults = 50,
  }) async {
    if (routePoints.length < 2 || types.isEmpty || maxResults <= 0) {
      return const AlongRouteResult(
        places: [],
        provider: 'geoapify',
        searchedPointCount: 0,
      );
    }

    if (_apiKey.isEmpty) {
      throw StateError(
        'Thiếu GEOAPIFY_API_KEY. Hãy chạy ứng dụng với --dart-define=GEOAPIFY_API_KEY=...',
      );
    }

    final radius = searchRadiusMeters.clamp(100.0, 100000.0).toDouble();
    final limit = maxResults.clamp(1, 500).toInt();
    final sampledRoute = _sampleRoutePoints(routePoints);
    final selectedTypes = AlongRoutePlaceType.values
        .where(types.contains)
        .toList(growable: false);

    if (selectedTypes.isEmpty) {
      return AlongRouteResult(
        places: const [],
        provider: 'geoapify',
        searchedPointCount: sampledRoute.length,
      );
    }

    final deduplicated = <String, AlongRoutePlace>{};
    final baseQuota = limit ~/ selectedTypes.length;
    var remainder = limit % selectedTypes.length;

    for (final type in selectedTypes) {
      final typeQuota = math
          .max(1, baseQuota + (remainder > 0 ? 1 : 0))
          .toInt();
      if (remainder > 0) {
        remainder--;
      }

      final batches = _categoryBatchesForType(type);
      if (batches.isEmpty) {
        continue;
      }

      final batchBaseQuota = typeQuota ~/ batches.length;
      var batchRemainder = typeQuota % batches.length;

      for (final categories in batches) {
        final batchQuota = math
            .max(1, batchBaseQuota + (batchRemainder > 0 ? 1 : 0))
            .toInt();
        if (batchRemainder > 0) {
          batchRemainder--;
        }

        final places = await _searchCategoryBatch(
          routePoints: sampledRoute,
          fullRoutePoints: routePoints,
          type: type,
          categories: categories,
          searchRadiusMeters: radius,
          maxResults: batchQuota,
        );

        for (final place in places) {
          final key = '${place.source}:${place.sourceId}';
          final existing = deduplicated[key];

          if (existing == null) {
            deduplicated[key] = place;
            continue;
          }

          final existingDistance =
              existing.distanceFromRouteMeters ?? double.infinity;
          final newDistance = place.distanceFromRouteMeters ?? double.infinity;

          if (newDistance < existingDistance) {
            deduplicated[key] = place;
          }
        }
      }
    }

    final places = deduplicated.values.toList(growable: false)
      ..sort((a, b) {
        final distanceCompare = (a.distanceFromRouteMeters ?? double.infinity)
            .compareTo(b.distanceFromRouteMeters ?? double.infinity);

        if (distanceCompare != 0) {
          return distanceCompare;
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return AlongRouteResult(
      places: List<AlongRoutePlace>.unmodifiable(places.take(limit)),
      provider: 'geoapify',
      searchedPointCount: sampledRoute.length,
    );
  }

  Future<List<AlongRoutePlace>> _searchCategoryBatch({
    required List<RoutePoint> routePoints,
    required List<RoutePoint> fullRoutePoints,
    required AlongRoutePlaceType type,
    required List<String> categories,
    required double searchRadiusMeters,
    required int maxResults,
  }) async {
    final coordinates = routePoints
        .map((point) => [point.longitude, point.latitude])
        .toList(growable: false);

    final body = <String, dynamic>{
      'categories': categories,
      'filter': {
        'type': 'polyline',
        'geometry': {'type': 'LineString', 'coordinates': coordinates},
        'buffer': searchRadiusMeters.round(),
      },
      'limit': maxResults.clamp(1, 500),
      'offset': 0,
      'lang': 'vi',
    };

    final response = await _client
        .post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'x-api-key': _apiKey,
            'User-Agent': 'PhuotThu/1.0',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Geoapify Places API lỗi HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Geoapify trả về dữ liệu không hợp lệ.');
    }

    final features = decoded['features'];
    if (features is! List) {
      return const [];
    }

    final places = <AlongRoutePlace>[];

    for (final rawFeature in features) {
      if (rawFeature is! Map) {
        continue;
      }

      final feature = Map<String, dynamic>.from(rawFeature);
      final place = _parseFeature(feature, type);
      if (place == null) {
        continue;
      }

      final distanceFromRouteMeters = _distanceToRouteMeters(
        latitude: place.latitude,
        longitude: place.longitude,
        routePoints: fullRoutePoints,
      );

      if (distanceFromRouteMeters > searchRadiusMeters + 10) {
        continue;
      }

      places.add(
        place.copyWith(distanceFromRouteMeters: distanceFromRouteMeters),
      );
    }

    return places;
  }

  List<List<String>> _categoryBatchesForType(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return const [
          ['service.vehicle.fuel'],
        ];

      case AlongRoutePlaceType.restArea:
        // "Nghỉ / lưu trú" trong PhuotThu là nơi ngủ nghỉ thực tế,
        // không còn dùng leisure.picnic.
        return const [
          [
            'accommodation.hotel',
            'accommodation.guest_house',
            'accommodation.motel',
            'accommodation.hostel',
          ],
        ];

      case AlongRoutePlaceType.food:
        // Tách ăn và uống thành hai batch để tránh một nhóm dày đặc
        // lấn át hoàn toàn nhóm còn lại trong giới hạn kết quả.
        return const [
          ['catering.restaurant', 'catering.fast_food', 'catering.food_court'],
          [
            'catering.cafe',
            'catering.bar',
            'catering.pub',
            'catering.biergarten',
          ],
        ];

      case AlongRoutePlaceType.repair:
        return const [
          ['service.vehicle.repair'],
        ];

      case AlongRoutePlaceType.medical:
        return const [
          ['healthcare.hospital', 'healthcare.clinic_or_praxis'],
        ];
    }
  }

  AlongRoutePlace? _parseFeature(
    Map<String, dynamic> feature,
    AlongRoutePlaceType type,
  ) {
    final geometry = feature['geometry'];
    final properties = feature['properties'];

    if (geometry is! Map || properties is! Map) {
      return null;
    }

    final geometryMap = Map<String, dynamic>.from(geometry);
    final propertiesMap = Map<String, dynamic>.from(properties);
    final coordinates = geometryMap['coordinates'];

    if (coordinates is! List || coordinates.length < 2) {
      return null;
    }

    final longitude = _toDouble(coordinates[0]);
    final latitude = _toDouble(coordinates[1]);

    if (latitude == null ||
        longitude == null ||
        !_isValidCoordinate(latitude, longitude)) {
      return null;
    }

    final sourceId = _firstNonEmpty([
      _stringValue(propertiesMap['place_id']),
      _stringValue(feature['id']),
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
    ])!;

    final name = _firstNonEmpty([
      _stringValue(propertiesMap['name']),
      _stringValue(propertiesMap['address_line1']),
      _stringValue(propertiesMap['formatted']),
      _fallbackName(type),
    ])!;

    final categories = _stringList(propertiesMap['categories']);
    final datasource = propertiesMap['datasource'];
    final datasourceMap = datasource is Map
        ? Map<String, dynamic>.from(datasource)
        : const <String, dynamic>{};
    final raw = datasourceMap['raw'];
    final rawMap = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};

    final address = _firstNonEmpty([
      _stringValue(propertiesMap['formatted']),
      _stringValue(propertiesMap['address_line2']),
    ]);

    final openingHours = _firstNonEmpty([
      _stringValue(propertiesMap['opening_hours']),
      _stringValue(rawMap['opening_hours']),
    ]);

    final phone = _firstNonEmpty([
      _stringValue(propertiesMap['phone']),
      _stringValue(rawMap['phone']),
      _stringValue(rawMap['contact:phone']),
      _stringValue(rawMap['mobile']),
    ]);

    final website = _firstNonEmpty([
      _stringValue(propertiesMap['website']),
      _stringValue(rawMap['website']),
      _stringValue(rawMap['contact:website']),
    ]);

    final tags = <String, String>{};
    if (categories.isNotEmpty) {
      tags['categories'] = categories.join(',');
    }

    final cuisine = _firstNonEmpty([
      _stringValue(
        propertiesMap['catering'] is Map
            ? (propertiesMap['catering'] as Map)['cuisine']
            : null,
      ),
      _stringValue(rawMap['cuisine']),
    ]);
    if (cuisine != null) {
      tags['cuisine'] = cuisine;
    }

    return AlongRoutePlace(
      id: 'geoapify:$sourceId',
      name: name,
      type: type,
      latitude: latitude,
      longitude: longitude,
      source: 'geoapify',
      sourceId: sourceId,
      address: address,
      openingHours: openingHours,
      phone: phone,
      website: website,
      tags: tags,
    );
  }

  List<RoutePoint> _sampleRoutePoints(List<RoutePoint> routePoints) {
    if (routePoints.length <= _maximumQueryPoints) {
      return List<RoutePoint>.unmodifiable(routePoints);
    }

    final sampled = <RoutePoint>[];
    final lastIndex = routePoints.length - 1;

    for (var i = 0; i < _maximumQueryPoints; i++) {
      final ratio = i / (_maximumQueryPoints - 1);
      final index = (ratio * lastIndex).round().clamp(0, lastIndex).toInt();
      final point = routePoints[index];

      if (sampled.isEmpty ||
          sampled.last.latitude != point.latitude ||
          sampled.last.longitude != point.longitude) {
        sampled.add(point);
      }
    }

    if (sampled.last.latitude != routePoints.last.latitude ||
        sampled.last.longitude != routePoints.last.longitude) {
      sampled.add(routePoints.last);
    }

    return List<RoutePoint>.unmodifiable(sampled);
  }

  double _distanceToRouteMeters({
    required double latitude,
    required double longitude,
    required List<RoutePoint> routePoints,
  }) {
    if (routePoints.isEmpty) {
      return double.infinity;
    }

    if (routePoints.length == 1) {
      return _haversineMeters(
        latitude,
        longitude,
        routePoints.first.latitude,
        routePoints.first.longitude,
      );
    }

    var bestDistance = double.infinity;

    for (var i = 0; i < routePoints.length - 1; i++) {
      final start = routePoints[i];
      final end = routePoints[i + 1];

      final distance = _distancePointToSegmentMeters(
        pointLatitude: latitude,
        pointLongitude: longitude,
        startLatitude: start.latitude,
        startLongitude: start.longitude,
        endLatitude: end.latitude,
        endLongitude: end.longitude,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
      }
    }

    return bestDistance;
  }

  double _distancePointToSegmentMeters({
    required double pointLatitude,
    required double pointLongitude,
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final referenceLatitude =
        ((pointLatitude + startLatitude + endLatitude) / 3) * math.pi / 180;

    double x(double longitude) =>
        longitude *
        math.pi /
        180 *
        _earthRadiusMeters *
        math.cos(referenceLatitude);
    double y(double latitude) => latitude * math.pi / 180 * _earthRadiusMeters;

    final px = x(pointLongitude);
    final py = y(pointLatitude);
    final ax = x(startLongitude);
    final ay = y(startLatitude);
    final bx = x(endLongitude);
    final by = y(endLatitude);

    final abx = bx - ax;
    final aby = by - ay;
    final lengthSquared = abx * abx + aby * aby;

    if (lengthSquared <= 0) {
      return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
    }

    final projection = (((px - ax) * abx + (py - ay) * aby) / lengthSquared)
        .clamp(0.0, 1.0);
    final closestX = ax + projection * abx;
    final closestY = ay + projection * aby;

    return math.sqrt(
      (px - closestX) * (px - closestX) + (py - closestY) * (py - closestY),
    );
  }

  double _haversineMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    final lat1 = latitude1 * math.pi / 180;
    final lat2 = latitude2 * math.pi / 180;
    final deltaLat = (latitude2 - latitude1) * math.pi / 180;
    final deltaLon = (longitude2 - longitude1) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  String _fallbackName(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return 'Cây xăng';
      case AlongRoutePlaceType.restArea:
        return 'Cơ sở lưu trú';
      case AlongRoutePlaceType.food:
        return 'Địa điểm ăn uống';
      case AlongRoutePlaceType.repair:
        return 'Điểm sửa chữa';
      case AlongRoutePlaceType.medical:
        return 'Cơ sở y tế';
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(_stringValue)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}
