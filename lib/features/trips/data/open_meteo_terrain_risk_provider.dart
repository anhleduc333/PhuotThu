import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../domain/connectivity_risk.dart';
import '../domain/connectivity_risk_evidence_provider.dart';

class TerrainRiskProxyPolicy {
  const TerrainRiskProxyPolicy({
    this.neighborhoodRadiusMeters = 1500,
    this.reliefRiskMaxMeters = 600,
    this.elevationRiskStartMeters = 500,
    this.elevationRiskMaxMeters = 2500,
    this.reliefWeight = 0.85,
    this.elevationWeight = 0.15,
    this.evidenceConfidence = 0.55,
  });

  /// Bán kính dùng để lấy 4 điểm xung quanh sample.
  final double neighborhoodRadiusMeters;

  /// Local relief đạt mức này được quy đổi thành terrain risk = 1.0.
  final double reliefRiskMaxMeters;

  /// Độ cao thấp hơn ngưỡng này không cộng thêm elevation risk.
  final double elevationRiskStartMeters;

  /// Độ cao đạt ngưỡng này được quy đổi elevation risk = 1.0.
  final double elevationRiskMaxMeters;

  final double reliefWeight;
  final double elevationWeight;

  /// Terrain chỉ là proxy cho connectivity risk nên confidence
  /// cố ý thấp hơn dữ liệu phủ sóng trực tiếp.
  final double evidenceConfidence;

  bool get isValid {
    return neighborhoodRadiusMeters > 0 &&
        reliefRiskMaxMeters > 0 &&
        elevationRiskMaxMeters > elevationRiskStartMeters &&
        reliefWeight >= 0 &&
        elevationWeight >= 0 &&
        reliefWeight + elevationWeight > 0 &&
        evidenceConfidence >= 0 &&
        evidenceConfidence <= 1;
  }
}

class OpenMeteoTerrainRiskProvider implements ConnectivityRiskEvidenceProvider {
  OpenMeteoTerrainRiskProvider(
    this._client, {
    this.policy = const TerrainRiskProxyPolicy(),
    Uri? endpoint,
    Duration? timeout,
  }) : _endpoint =
           endpoint ?? Uri.parse('https://api.open-meteo.com/v1/elevation'),
       _timeout = timeout ?? const Duration(seconds: 20);

  final http.Client _client;
  final TerrainRiskProxyPolicy policy;
  final Uri _endpoint;
  final Duration _timeout;

  @override
  String get providerId => 'open-meteo-terrain-proxy';

  @override
  Future<List<ConnectivityRiskEvidence>> getEvidence(
    ConnectivityRiskSampleLocation location,
  ) async {
    if (!policy.isValid) {
      throw StateError('TerrainRiskProxyPolicy không hợp lệ.');
    }

    final coordinates = _buildNeighborhood(location);

    final uri = _endpoint.replace(
      queryParameters: {
        'latitude': coordinates
            .map((item) => item.$1.toStringAsFixed(6))
            .join(','),
        'longitude': coordinates
            .map((item) => item.$2.toStringAsFixed(6))
            .join(','),
      },
    );

    final response = await _client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'PhuotThu/1.0',
          },
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Open-Meteo Elevation API lỗi HTTP ${response.statusCode}: '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Open-Meteo trả về dữ liệu elevation không hợp lệ.',
      );
    }

    final rawElevations = decoded['elevation'];

    if (rawElevations is! List || rawElevations.length < coordinates.length) {
      throw const FormatException('Open-Meteo không trả đủ dữ liệu elevation.');
    }

    final elevations = <double>[];

    for (var index = 0; index < coordinates.length; index++) {
      final value = _toDouble(rawElevations[index]);

      if (value == null || !value.isFinite) {
        throw const FormatException(
          'Open-Meteo trả về elevation không hợp lệ.',
        );
      }

      elevations.add(value);
    }

    final centerElevation = elevations.first;
    final minElevation = elevations.reduce(math.min);
    final maxElevation = elevations.reduce(math.max);
    final localReliefMeters = maxElevation - minElevation;

    final reliefRisk = (localReliefMeters / policy.reliefRiskMaxMeters).clamp(
      0.0,
      1.0,
    );

    final elevationRisk =
        ((centerElevation - policy.elevationRiskStartMeters) /
                (policy.elevationRiskMaxMeters -
                    policy.elevationRiskStartMeters))
            .clamp(0.0, 1.0);

    final totalWeight = policy.reliefWeight + policy.elevationWeight;

    final riskScore =
        ((reliefRisk * policy.reliefWeight +
                    elevationRisk * policy.elevationWeight) /
                totalWeight)
            .clamp(0.0, 1.0);

    return [
      ConnectivityRiskEvidence(
        type: ConnectivityRiskEvidenceType.terrain,
        riskScore: riskScore,
        confidence: policy.evidenceConfidence,
        source: 'open_meteo_copernicus_dem_proxy',
        description:
            'Ước lượng địa hình: cao độ trung tâm '
            '${centerElevation.round()} m, local relief '
            '${localReliefMeters.round()} m trong bán kính '
            '${policy.neighborhoodRadiusMeters.round()} m. '
            'Đây là proxy địa hình, không phải dữ liệu phủ sóng nhà mạng.',
      ),
    ];
  }

  List<(double, double)> _buildNeighborhood(
    ConnectivityRiskSampleLocation location,
  ) {
    final latitude = location.latitude;
    final longitude = location.longitude;

    final latitudeDelta = policy.neighborhoodRadiusMeters / 111320.0;

    final cosine = math.cos(latitude * math.pi / 180).abs();
    final safeCosine = math.max(cosine, 0.01);

    final longitudeDelta =
        policy.neighborhoodRadiusMeters / (111320.0 * safeCosine);

    return [
      (latitude, longitude),
      ((latitude + latitudeDelta).clamp(-90.0, 90.0), longitude),
      ((latitude - latitudeDelta).clamp(-90.0, 90.0), longitude),
      (latitude, _normalizeLongitude(longitude + longitudeDelta)),
      (latitude, _normalizeLongitude(longitude - longitudeDelta)),
    ];
  }

  double _normalizeLongitude(double longitude) {
    var value = longitude;

    while (value > 180) {
      value -= 360;
    }

    while (value < -180) {
      value += 360;
    }

    return value;
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
}
