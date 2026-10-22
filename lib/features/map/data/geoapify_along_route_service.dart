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
    required this._apiKey,
    Uri? endpoint,
  }) : _endpoint = endpoint ?? Uri.parse('https://api.geoapify.com/v2/places');

  final http.Client _client;
  final String _apiKey;
  final Uri _endpoint;

  static const Duration _requestTimeout = Duration(seconds: 30);

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
    if (routePoints.isEmpty || types.isEmpty || maxResults <= 0) {
      return const AlongRouteResult(
        places: [],
        provider: 'geoapify',
        searchedPointCount: 0,
      );
    }

    if (_apiKey.trim().isEmpty) {
      throw const GeoapifyAlongRouteException(
        'Geoapify API key chưa được cấu hình.',
      );
    }

    final radius = searchRadiusMeters.clamp(100.0, 100000.0).toDouble();

    final resultLimit = maxResults.clamp(1, 500).toInt();

    final queryPoints = _sampleRoutePoints(
      routePoints,
      maxPoints: _maximumQueryPoints,
    );

    final selectedTypes = AlongRoutePlaceType.values
        .where(types.contains)
        .toList(growable: false);

    if (selectedTypes.isEmpty) {
      return AlongRouteResult(
        places: const [],
        provider: 'geoapify',
        searchedPointCount: queryPoints.length,
      );
    }

    final quotas = _buildTypeQuotas(
      selectedTypes: selectedTypes,
      maxResults: resultLimit,
    );

    final deduplicated = <String, AlongRoutePlace>{};

    for (final type in selectedTypes) {
      final typeLimit = quotas[type] ?? 0;

      if (typeLimit <= 0) {
        continue;
      }

      final places = await _searchType(
        type: type,
        routePoints: routePoints,
        queryPoints: queryPoints,
        searchRadiusMeters: radius,
        maxResults: typeLimit,
      );

      for (final place in places) {
        final existing = deduplicated[place.sourceId];

        if (existing == null) {
          deduplicated[place.sourceId] = place;
          continue;
        }

        final existingDistance =
            existing.distanceFromRouteMeters ?? double.infinity;

        final newDistance = place.distanceFromRouteMeters ?? double.infinity;

        if (newDistance < existingDistance) {
          deduplicated[place.sourceId] = place;
        }
      }
    }

    final places = deduplicated.values.toList()
      ..sort((a, b) {
        final distanceCompare = (a.distanceFromRouteMeters ?? double.infinity)
            .compareTo(b.distanceFromRouteMeters ?? double.infinity);

        if (distanceCompare != 0) {
          return distanceCompare;
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return AlongRouteResult(
      places: List<AlongRoutePlace>.unmodifiable(places.take(resultLimit)),
      provider: 'geoapify',
      searchedPointCount: queryPoints.length,
    );
  }

  Map<AlongRoutePlaceType, int> _buildTypeQuotas({
    required List<AlongRoutePlaceType> selectedTypes,
    required int maxResults,
  }) {
    final quotas = <AlongRoutePlaceType, int>{};

    if (selectedTypes.isEmpty || maxResults <= 0) {
      return quotas;
    }

    final baseQuota = maxResults ~/ selectedTypes.length;
    final remainder = maxResults % selectedTypes.length;

    for (var i = 0; i < selectedTypes.length; i++) {
      quotas[selectedTypes[i]] = baseQuota + (i < remainder ? 1 : 0);
    }

    return quotas;
  }

  Future<List<AlongRoutePlace>> _searchType({
    required AlongRoutePlaceType type,
    required List<RoutePoint> routePoints,
    required List<RoutePoint> queryPoints,
    required double searchRadiusMeters,
    required int maxResults,
  }) async {
    final categories = _categoriesForType(type);

    if (categories.isEmpty || maxResults <= 0) {
      return const [];
    }

    final body = <String, dynamic>{
      'categories': categories,
      'filter': {
        'type': 'polyline',
        'geometry': {
          'type': 'LineString',
          'coordinates': queryPoints
              .map((point) => [point.longitude, point.latitude])
              .toList(),
        },
        'buffer': searchRadiusMeters.round(),
      },
      'limit': maxResults,
      'offset': 0,
      'lang': 'vi',
    };

    try {
      final response = await _client
          .post(
            _endpoint,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'x-api-key': _apiKey,
              'User-Agent':
                  'PhuotThu/0.1 '
                  '(com.anhleduc333.phuotthu)',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw GeoapifyAlongRouteException(
          _httpErrorMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const GeoapifyAlongRouteException(
          'Geoapify trả về dữ liệu không hợp lệ.',
        );
      }

      final rawFeatures = decoded['features'];

      if (rawFeatures is! List) {
        return const [];
      }

      final places = <AlongRoutePlace>[];
      final seenPlaceIds = <String>{};

      for (final rawFeature in rawFeatures) {
        if (rawFeature is! Map) {
          continue;
        }

        final feature = Map<String, dynamic>.from(rawFeature);

        final place = _parseFeature(feature, requestedType: type);

        if (place == null) {
          continue;
        }

        if (!seenPlaceIds.add(place.sourceId)) {
          continue;
        }

        final distanceFromRoute = _distanceToRouteMeters(
          latitude: place.latitude,
          longitude: place.longitude,
          routePoints: routePoints,
        );

        if (distanceFromRoute > searchRadiusMeters + 10) {
          continue;
        }

        places.add(place.copyWith(distanceFromRouteMeters: distanceFromRoute));
      }

      places.sort((a, b) {
        final distanceCompare = (a.distanceFromRouteMeters ?? double.infinity)
            .compareTo(b.distanceFromRouteMeters ?? double.infinity);

        if (distanceCompare != 0) {
          return distanceCompare;
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return List<AlongRoutePlace>.unmodifiable(places.take(maxResults));
    } on GeoapifyAlongRouteException {
      rethrow;
    } on FormatException catch (error) {
      throw GeoapifyAlongRouteException(
        'Không thể đọc dữ liệu Geoapify cho '
        '${type.label}: ${error.message}',
      );
    } catch (error) {
      throw GeoapifyAlongRouteException(
        'Không thể tìm ${type.label.toLowerCase()} '
        'dọc tuyến: $error',
      );
    }
  }

  List<String> _categoriesForType(AlongRoutePlaceType type) {
    switch (type) {
      case AlongRoutePlaceType.fuel:
        return const ['service.vehicle.fuel'];

      case AlongRoutePlaceType.restArea:
        return const ['leisure.picnic'];

      case AlongRoutePlaceType.food:
        return const [
          'catering.restaurant',
          'catering.cafe',
          'catering.fast_food',
          'catering.food_court',
        ];

      case AlongRoutePlaceType.repair:
        return const ['service.vehicle.repair'];

      case AlongRoutePlaceType.medical:
        return const ['healthcare.hospital', 'healthcare.clinic_or_praxis'];
    }
  }

  AlongRoutePlace? _parseFeature(
    Map<String, dynamic> feature, {
    required AlongRoutePlaceType requestedType,
  }) {
    final rawProperties = feature['properties'];

    if (rawProperties is! Map) {
      return null;
    }

    final properties = Map<String, dynamic>.from(rawProperties);

    final categories = _stringList(properties['categories']);

    if (!_matchesRequestedType(categories: categories, type: requestedType)) {
      return null;
    }

    final latitude = _toDouble(properties['lat']);

    final longitude = _toDouble(properties['lon']);

    final coordinates = _geometryCoordinates(feature['geometry']);

    final resolvedLatitude = latitude ?? coordinates?.$2;

    final resolvedLongitude = longitude ?? coordinates?.$1;

    if (resolvedLatitude == null || resolvedLongitude == null) {
      return null;
    }

    final placeId = _stringValue(properties['place_id']);

    final fallbackId =
        '${resolvedLatitude.toStringAsFixed(6)},'
        '${resolvedLongitude.toStringAsFixed(6)},'
        '${requestedType.key}';

    final sourceId = placeId ?? fallbackId;

    final name =
        _firstNonEmpty([
          _stringValue(properties['name']),
          _stringValue(properties['address_line1']),
        ]) ??
        requestedType.label;

    final address = _firstNonEmpty([
      _stringValue(properties['formatted']),
      _combineAddressLines(properties),
    ]);

    final contact = _mapValue(properties['contact']);

    final phone = _firstNonEmpty([
      _stringValue(contact?['phone']),
      _stringValue(properties['phone']),
    ]);

    final website = _firstNonEmpty([
      _stringValue(properties['website']),
      _stringValue(contact?['website']),
    ]);

    final openingHours = _stringValue(properties['opening_hours']);

    final tags = <String, String>{
      'provider': 'geoapify',
      'type': requestedType.key,
    };

    if (categories.isNotEmpty) {
      tags['categories'] = categories.join(',');
    }

    if (placeId != null) {
      tags['place_id'] = placeId;
    }

    return AlongRoutePlace(
      id: 'geoapify:$sourceId',
      name: name,
      type: requestedType,
      latitude: resolvedLatitude,
      longitude: resolvedLongitude,
      source: 'geoapify',
      sourceId: sourceId,
      address: address,
      openingHours: openingHours,
      phone: phone,
      website: website,
      tags: tags,
    );
  }

  bool _matchesRequestedType({
    required List<String> categories,
    required AlongRoutePlaceType type,
  }) {
    bool hasCategory(String prefix) {
      return categories.any(
        (category) => category == prefix || category.startsWith('$prefix.'),
      );
    }

    switch (type) {
      case AlongRoutePlaceType.fuel:
        return hasCategory('service.vehicle.fuel');

      case AlongRoutePlaceType.restArea:
        return hasCategory('leisure.picnic');

      case AlongRoutePlaceType.food:
        return hasCategory('catering');

      case AlongRoutePlaceType.repair:
        return hasCategory('service.vehicle.repair');

      case AlongRoutePlaceType.medical:
        return hasCategory('healthcare');
    }
  }

  (double, double)? _geometryCoordinates(dynamic rawGeometry) {
    if (rawGeometry is! Map) {
      return null;
    }

    final geometry = Map<String, dynamic>.from(rawGeometry);

    if (geometry['type'] != 'Point') {
      return null;
    }

    final rawCoordinates = geometry['coordinates'];

    if (rawCoordinates is! List || rawCoordinates.length < 2) {
      return null;
    }

    final longitude = _toDouble(rawCoordinates[0]);

    final latitude = _toDouble(rawCoordinates[1]);

    if (longitude == null || latitude == null) {
      return null;
    }

    return (longitude, latitude);
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(value);
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  String? _combineAddressLines(Map<String, dynamic> properties) {
    final line1 = _stringValue(properties['address_line1']);

    final line2 = _stringValue(properties['address_line2']);

    final parts = <String>[];

    if (line1 != null) {
      parts.add(line1);
    }

    if (line2 != null) {
      parts.add(line2);
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }

  String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }

  String? _firstNonEmpty(Iterable<String?> values) {
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

    return double.tryParse(value?.toString() ?? '');
  }

  List<RoutePoint> _sampleRoutePoints(
    List<RoutePoint> routePoints, {
    required int maxPoints,
  }) {
    if (routePoints.length <= maxPoints) {
      return List<RoutePoint>.unmodifiable(routePoints);
    }

    if (maxPoints <= 2) {
      return [routePoints.first, routePoints.last];
    }

    final cumulativeDistances = List<double>.filled(routePoints.length, 0);

    for (var i = 1; i < routePoints.length; i++) {
      cumulativeDistances[i] =
          cumulativeDistances[i - 1] +
          _haversineMeters(routePoints[i - 1], routePoints[i]);
    }

    final totalDistance = cumulativeDistances.last;

    if (totalDistance <= 0) {
      return [routePoints.first, routePoints.last];
    }

    final sampled = <RoutePoint>[routePoints.first];

    final targetStep = totalDistance / (maxPoints - 1);

    var nextTarget = targetStep;

    for (
      var i = 1;
      i < routePoints.length - 1 && sampled.length < maxPoints - 1;
      i++
    ) {
      if (cumulativeDistances[i] >= nextTarget) {
        sampled.add(routePoints[i]);

        nextTarget += targetStep;
      }
    }

    sampled.add(routePoints.last);

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
      return _haversineCoordinatesMeters(
        latitude,
        longitude,
        routePoints.first.latitude,
        routePoints.first.longitude,
      );
    }

    var minimum = double.infinity;

    for (var i = 1; i < routePoints.length; i++) {
      final distance = _distanceToSegmentMeters(
        pointLatitude: latitude,
        pointLongitude: longitude,
        start: routePoints[i - 1],
        end: routePoints[i],
      );

      if (distance < minimum) {
        minimum = distance;
      }

      if (minimum <= 1) {
        return minimum;
      }
    }

    return minimum;
  }

  double _distanceToSegmentMeters({
    required double pointLatitude,
    required double pointLongitude,
    required RoutePoint start,
    required RoutePoint end,
  }) {
    final latitudeRadians = _degreesToRadians(pointLatitude);

    final startX =
        _earthRadiusMeters *
        _degreesToRadians(start.longitude - pointLongitude) *
        math.cos(latitudeRadians);

    final startY =
        _earthRadiusMeters * _degreesToRadians(start.latitude - pointLatitude);

    final endX =
        _earthRadiusMeters *
        _degreesToRadians(end.longitude - pointLongitude) *
        math.cos(latitudeRadians);

    final endY =
        _earthRadiusMeters * _degreesToRadians(end.latitude - pointLatitude);

    final segmentX = endX - startX;
    final segmentY = endY - startY;

    final segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

    if (segmentLengthSquared == 0) {
      return math.sqrt(startX * startX + startY * startY);
    }

    final projection =
        (-(startX * segmentX + startY * segmentY) / segmentLengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();

    final closestX = startX + projection * segmentX;
    final closestY = startY + projection * segmentY;

    return math.sqrt(closestX * closestX + closestY * closestY);
  }

  double _haversineMeters(RoutePoint a, RoutePoint b) {
    return _haversineCoordinatesMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  double _haversineCoordinatesMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    final lat1 = _degreesToRadians(latitude1);
    final lat2 = _degreesToRadians(latitude2);

    final deltaLatitude = _degreesToRadians(latitude2 - latitude1);

    final deltaLongitude = _degreesToRadians(longitude2 - longitude1);

    final sinLatitude = math.sin(deltaLatitude / 2);

    final sinLongitude = math.sin(deltaLongitude / 2);

    final haversine =
        sinLatitude * sinLatitude +
        math.cos(lat1) * math.cos(lat2) * sinLongitude * sinLongitude;

    final angularDistance =
        2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));

    return _earthRadiusMeters * angularDistance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  String _httpErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Yêu cầu Geoapify không hợp lệ.';

      case 401:
      case 403:
        return 'Geoapify API key không hợp lệ '
            'hoặc không có quyền truy cập.';

      case 429:
        return 'Đã vượt giới hạn truy vấn Geoapify. '
            'Vui lòng thử lại sau.';

      case 500:
      case 502:
      case 503:
      case 504:
        return 'Geoapify đang tạm thời không phản hồi. '
            'Vui lòng thử lại sau.';

      default:
        return 'Geoapify trả về lỗi HTTP $statusCode.';
    }
  }
}

class GeoapifyAlongRouteException implements Exception {
  const GeoapifyAlongRouteException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message (HTTP $statusCode)';
  }
}
