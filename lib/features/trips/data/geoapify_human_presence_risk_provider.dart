import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/connectivity_risk.dart';
import '../domain/connectivity_risk_evidence_provider.dart';

class HumanPresenceRiskProxyPolicy {
  const HumanPresenceRiskProxyPolicy({
    this.searchRadiusMeters = 5000,
    this.densePresenceCount = 25,
    this.isolationSafeDistanceMeters = 500,
    this.isolationMaxDistanceMeters = 5000,
    this.maxResults = 100,
    this.settlementEvidenceConfidence = 0.45,
    this.roadIsolationEvidenceConfidence = 0.45,
  });

  /// Bán kính tìm dấu hiệu dân cư/dịch vụ quanh sample.
  final double searchRadiusMeters;

  /// Khi số POI đạt ngưỡng này, settlement risk về gần 0.
  final int densePresenceCount;

  /// Khoảng cách tới POI gần nhất nhỏ hơn ngưỡng này
  /// được coi là không biệt lập theo proxy.
  final double isolationSafeDistanceMeters;

  /// Khoảng cách tới POI gần nhất đạt ngưỡng này
  /// được coi là isolation risk = 1.
  final double isolationMaxDistanceMeters;

  final int maxResults;

  /// Confidence cố ý ở mức trung bình vì đây chỉ là proxy từ POI.
  final double settlementEvidenceConfidence;
  final double roadIsolationEvidenceConfidence;

  bool get isValid {
    return searchRadiusMeters > 0 &&
        densePresenceCount > 0 &&
        isolationSafeDistanceMeters >= 0 &&
        isolationMaxDistanceMeters > isolationSafeDistanceMeters &&
        isolationMaxDistanceMeters <= searchRadiusMeters &&
        maxResults > 0 &&
        maxResults <= 500 &&
        settlementEvidenceConfidence >= 0 &&
        settlementEvidenceConfidence <= 1 &&
        roadIsolationEvidenceConfidence >= 0 &&
        roadIsolationEvidenceConfidence <= 1;
  }
}

class GeoapifyHumanPresenceRiskProvider
    implements ConnectivityRiskEvidenceProvider {
  GeoapifyHumanPresenceRiskProvider(
    this._client, {
    required String apiKey,
    this.policy = const HumanPresenceRiskProxyPolicy(),
    Uri? endpoint,
    Duration? timeout,
  }) : _apiKey = apiKey.trim(),
       _endpoint = endpoint ?? Uri.parse('https://api.geoapify.com/v2/places'),
       _timeout = timeout ?? const Duration(seconds: 20);

  final http.Client _client;
  final String _apiKey;
  final HumanPresenceRiskProxyPolicy policy;
  final Uri _endpoint;
  final Duration _timeout;

  static const double _earthRadiusMeters = 6371000;

  /// Các category này chỉ đại diện cho "dấu hiệu hiện diện con người".
  /// Chúng không phải dữ liệu dân số chính thức.
  static const List<String> _presenceCategories = [
    'populated_place',
    'commercial',
    'catering',
    'healthcare',
    'education',
    'public_transport',
    'accommodation',
    'service.vehicle.fuel',
    'service.vehicle.repair',
  ];

  @override
  String get providerId => 'geoapify-human-presence-proxy';

  @override
  Future<List<ConnectivityRiskEvidence>> getEvidence(
    ConnectivityRiskSampleLocation location,
  ) async {
    if (_apiKey.isEmpty) {
      throw StateError('Thiếu GEOAPIFY_API_KEY.');
    }

    if (!policy.isValid) {
      throw StateError('HumanPresenceRiskProxyPolicy không hợp lệ.');
    }

    final body = <String, dynamic>{
      'categories': _presenceCategories,
      'filter': {
        'type': 'circle',
        'lon': location.longitude,
        'lat': location.latitude,
        'radius': policy.searchRadiusMeters.round(),
      },
      'bias': {
        'type': 'proximity',
        'lon': location.longitude,
        'lat': location.latitude,
      },
      'limit': policy.maxResults,
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
        'Geoapify Places API lỗi HTTP ${response.statusCode}: '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Geoapify trả về dữ liệu human-presence không hợp lệ.',
      );
    }

    final rawFeatures = decoded['features'];

    if (rawFeatures is! List) {
      throw const FormatException(
        'Geoapify không trả về danh sách features hợp lệ.',
      );
    }

    final uniquePlaces = <String, _PresencePlace>{};

    for (final rawFeature in rawFeatures) {
      if (rawFeature is! Map) {
        continue;
      }

      final feature = Map<String, dynamic>.from(rawFeature);
      final place = _parsePlace(feature, location);

      if (place == null) {
        continue;
      }

      final existing = uniquePlaces[place.id];

      if (existing == null || place.distanceMeters < existing.distanceMeters) {
        uniquePlaces[place.id] = place;
      }
    }

    final places = uniquePlaces.values.toList(growable: false);
    final placeCount = places.length;

    final settlementRisk = (1 - (placeCount / policy.densePresenceCount)).clamp(
      0.0,
      1.0,
    );

    final nearestDistanceMeters = places.isEmpty
        ? policy.searchRadiusMeters
        : places.map((place) => place.distanceMeters).reduce(math.min);

    final roadIsolationRisk =
        ((nearestDistanceMeters - policy.isolationSafeDistanceMeters) /
                (policy.isolationMaxDistanceMeters -
                    policy.isolationSafeDistanceMeters))
            .clamp(0.0, 1.0);

    final nearestLabel = places.isEmpty
        ? 'không tìm thấy POI trong ${policy.searchRadiusMeters.round()} m'
        : 'POI gần nhất cách ${nearestDistanceMeters.round()} m';

    return [
      ConnectivityRiskEvidence(
        type: ConnectivityRiskEvidenceType.settlementDensity,
        riskScore: settlementRisk,
        confidence: policy.settlementEvidenceConfidence,
        source: 'geoapify_human_presence_proxy',
        description:
            'Proxy hiện diện dân cư/dịch vụ: tìm thấy $placeCount POI '
            'trong bán kính ${policy.searchRadiusMeters.round()} m. '
            'Đây không phải dữ liệu dân số chính thức.',
      ),
      ConnectivityRiskEvidence(
        type: ConnectivityRiskEvidenceType.roadIsolation,
        riskScore: roadIsolationRisk,
        confidence: policy.roadIsolationEvidenceConfidence,
        source: 'geoapify_human_presence_proxy',
        description:
            'Proxy mức độ biệt lập: $nearestLabel. '
            'Đây là ước lượng dựa trên POI lân cận, không phải dữ liệu '
            'phủ sóng hay đánh giá khả năng tiếp cận đường bộ chính thức.',
      ),
    ];
  }

  _PresencePlace? _parsePlace(
    Map<String, dynamic> feature,
    ConnectivityRiskSampleLocation location,
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

    final id = _firstNonEmpty([
      _stringValue(propertiesMap['place_id']),
      _stringValue(feature['id']),
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
    ]);

    if (id == null) {
      return null;
    }

    final distanceMeters = _haversineMeters(
      location.latitude,
      location.longitude,
      latitude,
      longitude,
    );

    if (distanceMeters > policy.searchRadiusMeters + 10) {
      return null;
    }

    return _PresencePlace(id: id, distanceMeters: distanceMeters);
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

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
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

  String? _stringValue(dynamic value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }
}

class _PresencePlace {
  const _PresencePlace({required this.id, required this.distanceMeters});

  final String id;
  final double distanceMeters;
}
