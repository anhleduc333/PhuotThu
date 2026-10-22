import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/along_route_place.dart';
import '../domain/along_route_result.dart';
import '../domain/route_result.dart';
import 'along_route_service.dart';

class OverpassAlongRouteService implements AlongRouteService {
  OverpassAlongRouteService(this._client, {Uri? endpoint})
    : _endpoint =
          endpoint ?? Uri.parse('https://overpass-api.de/api/interpreter');

  final http.Client _client;
  final Uri _endpoint;

  DateTime? _lastRequestAt;
  bool _requestInProgress = false;

  static const Duration _minimumRequestInterval = Duration(seconds: 2);

  static const Duration _requestTimeout = Duration(seconds: 40);

  /// Giới hạn số điểm tuyến gửi vào Overpass.
  ///
  /// Tuyến OSRM có thể chứa hàng nghìn điểm.
  /// Không nên gửi toàn bộ lên public Overpass.
  static const int _maximumQueryPoints = 100;

  static const double _earthRadiusMeters = 6371000;

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
        provider: 'overpass',
        searchedPointCount: 0,
      );
    }

    if (_requestInProgress) {
      throw const OverpassAlongRouteException(
        'Một truy vấn Along Route khác đang chạy.',
      );
    }

    final radius = searchRadiusMeters.clamp(250.0, 10000.0).toDouble();

    final resultLimit = maxResults.clamp(1, 100).toInt();

    final queryPoints = _sampleRoutePoints(
      routePoints,
      maxPoints: _maximumQueryPoints,
    );

    final query = _buildQuery(
      routePoints: queryPoints,
      types: types,
      searchRadiusMeters: radius,
      maxResults: resultLimit,
    );

    await _respectRequestInterval();

    _requestInProgress = true;

    try {
      final response = await _client
          .post(
            _endpoint,
            headers: const {
              'Accept': 'application/json',
              'User-Agent':
                  'PhuotThu/0.1 '
                  '(com.anhleduc333.phuotthu)',
            },
            body: {'data': query},
          )
          .timeout(_requestTimeout);

      _lastRequestAt = DateTime.now();

      if (response.statusCode != 200) {
        throw OverpassAlongRouteException(
          _httpErrorMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw const OverpassAlongRouteException(
          'Overpass trả về dữ liệu không hợp lệ.',
        );
      }

      final rawElements = decoded['elements'];

      if (rawElements is! List) {
        return AlongRouteResult(
          places: const [],
          provider: 'overpass',
          searchedPointCount: queryPoints.length,
        );
      }

      final deduplicated = <String, AlongRoutePlace>{};

      for (final rawElement in rawElements) {
        if (rawElement is! Map<String, dynamic>) {
          continue;
        }

        final place = _parseElement(rawElement);

        if (place == null) {
          continue;
        }

        final distanceFromRoute = _distanceToRouteMeters(
          latitude: place.latitude,
          longitude: place.longitude,
          routePoints: routePoints,
        );

        // Overpass tìm theo tuyến đã được rút gọn.
        // Lọc lại bằng tuyến OSRM đầy đủ để loại POI
        // thực tế nằm ngoài bán kính yêu cầu.
        if (distanceFromRoute > radius) {
          continue;
        }

        final enriched = place.copyWith(
          distanceFromRouteMeters: distanceFromRoute,
        );

        final uniqueKey = '${place.source}:${place.sourceId}';

        final existing = deduplicated[uniqueKey];

        if (existing == null) {
          deduplicated[uniqueKey] = enriched;
          continue;
        }

        final oldDistance = existing.distanceFromRouteMeters ?? double.infinity;

        if (distanceFromRoute < oldDistance) {
          deduplicated[uniqueKey] = enriched;
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

      final limitedPlaces = places.take(resultLimit);

      return AlongRouteResult(
        places: List<AlongRoutePlace>.unmodifiable(limitedPlaces),
        provider: 'overpass',
        searchedPointCount: queryPoints.length,
      );
    } on OverpassAlongRouteException {
      rethrow;
    } on FormatException catch (error) {
      throw OverpassAlongRouteException(
        'Không thể đọc dữ liệu Overpass: '
        '${error.message}',
      );
    } catch (error) {
      throw OverpassAlongRouteException(
        'Không thể tìm dịch vụ dọc tuyến: '
        '$error',
      );
    } finally {
      _requestInProgress = false;
    }
  }

  Future<void> _respectRequestInterval() async {
    final lastRequest = _lastRequestAt;

    if (lastRequest == null) {
      return;
    }

    final elapsed = DateTime.now().difference(lastRequest);

    if (elapsed >= _minimumRequestInterval) {
      return;
    }

    await Future<void>.delayed(_minimumRequestInterval - elapsed);
  }

  String _buildQuery({
    required List<RoutePoint> routePoints,
    required Set<AlongRoutePlaceType> types,
    required double searchRadiusMeters,
    required int maxResults,
  }) {
    final coordinateString = routePoints
        .map(
          (point) =>
              '${point.latitude.toStringAsFixed(6)},'
              '${point.longitude.toStringAsFixed(6)}',
        )
        .join(',');

    final radius = searchRadiusMeters.round();

    final statements = <String>[];

    void addQuery(String filter) {
      statements.add(
        'nwr$filter'
        '(around:$radius,$coordinateString);',
      );
    }

    if (types.contains(AlongRoutePlaceType.fuel)) {
      addQuery('["amenity"="fuel"]');
    }

    if (types.contains(AlongRoutePlaceType.restArea)) {
      addQuery('["highway"="rest_area"]');
    }

    if (types.contains(AlongRoutePlaceType.food)) {
      addQuery('["amenity"="restaurant"]');

      addQuery('["amenity"="cafe"]');

      addQuery('["amenity"="fast_food"]');
    }

    if (types.contains(AlongRoutePlaceType.repair)) {
      addQuery('["shop"="car_repair"]');
    }

    if (types.contains(AlongRoutePlaceType.medical)) {
      addQuery('["amenity"="hospital"]');

      addQuery('["amenity"="clinic"]');

      addQuery('["amenity"="doctors"]');
    }

    // Lấy dư hơn maxResults một chút vì sau đó
    // ứng dụng còn lọc chính xác theo tuyến OSRM.
    final serverOutputLimit = math.min(math.max(maxResults * 4, 50), 250);

    return '''
[out:json][timeout:30];
(
${statements.join('\n')}
);
out center tags $serverOutputLimit;
''';
  }

  AlongRoutePlace? _parseElement(Map<String, dynamic> element) {
    final osmType = element['type']?.toString();

    final rawId = element['id'];

    if (osmType == null || rawId == null) {
      return null;
    }

    double? latitude;
    double? longitude;

    if (osmType == 'node') {
      latitude = _toDouble(element['lat']);

      longitude = _toDouble(element['lon']);
    } else {
      final center = element['center'];

      if (center is Map<String, dynamic>) {
        latitude = _toDouble(center['lat']);

        longitude = _toDouble(center['lon']);
      } else if (center is Map) {
        latitude = _toDouble(center['lat']);

        longitude = _toDouble(center['lon']);
      }
    }

    if (latitude == null || longitude == null) {
      return null;
    }

    final tags = _parseTags(element['tags']);

    final type = _classify(tags);

    if (type == null) {
      return null;
    }

    final sourceId = '$osmType/$rawId';

    final name =
        _firstNonEmpty([tags['name'], tags['brand'], tags['operator']]) ??
        type.label;

    return AlongRoutePlace(
      id: 'overpass:$sourceId',
      name: name,
      type: type,
      latitude: latitude,
      longitude: longitude,
      source: 'overpass',
      sourceId: sourceId,
      address: _buildAddress(tags),
      openingHours: _nullableTag(tags['opening_hours']),
      phone: _firstNonEmpty([tags['phone'], tags['contact:phone']]),
      website: _firstNonEmpty([tags['website'], tags['contact:website']]),
      tags: tags,
    );
  }

  AlongRoutePlaceType? _classify(Map<String, String> tags) {
    final amenity = tags['amenity'];

    final highway = tags['highway'];

    final shop = tags['shop'];

    if (amenity == 'fuel') {
      return AlongRoutePlaceType.fuel;
    }

    if (highway == 'rest_area') {
      return AlongRoutePlaceType.restArea;
    }

    if (shop == 'car_repair') {
      return AlongRoutePlaceType.repair;
    }

    if (amenity == 'hospital' || amenity == 'clinic' || amenity == 'doctors') {
      return AlongRoutePlaceType.medical;
    }

    if (amenity == 'restaurant' ||
        amenity == 'cafe' ||
        amenity == 'fast_food') {
      return AlongRoutePlaceType.food;
    }

    return null;
  }

  Map<String, String> _parseTags(dynamic rawTags) {
    if (rawTags is! Map) {
      return const {};
    }

    final tags = <String, String>{};

    for (final entry in rawTags.entries) {
      final key = entry.key?.toString();

      final value = entry.value?.toString();

      if (key == null || value == null) {
        continue;
      }

      tags[key] = value;
    }

    return tags;
  }

  String? _buildAddress(Map<String, String> tags) {
    final fullAddress = _nullableTag(tags['addr:full']);

    if (fullAddress != null) {
      return fullAddress;
    }

    final parts = <String>[
      if (_nullableTag(tags['addr:housenumber']) != null)
        tags['addr:housenumber']!,
      if (_nullableTag(tags['addr:street']) != null) tags['addr:street']!,
      if (_nullableTag(tags['addr:ward']) != null) tags['addr:ward']!,
      if (_nullableTag(tags['addr:district']) != null) tags['addr:district']!,
      if (_nullableTag(tags['addr:city']) != null) tags['addr:city']!,
      if (_nullableTag(tags['addr:province']) != null) tags['addr:province']!,
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }

  String? _nullableTag(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final normalized = _nullableTag(value);

      if (normalized != null) {
        return normalized;
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
        return 'Truy vấn Overpass không hợp lệ.';
      case 429:
        return 'Overpass đang giới hạn số lượng truy vấn. '
            'Vui lòng thử lại sau.';
      case 504:
        return 'Overpass mất quá nhiều thời gian xử lý. '
            'Hãy thử lại với phạm vi nhỏ hơn.';
      default:
        return 'Overpass trả về lỗi HTTP $statusCode.';
    }
  }
}

class OverpassAlongRouteException implements Exception {
  const OverpassAlongRouteException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message '
        '(HTTP $statusCode)';
  }
}
