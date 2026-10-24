import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phuotthu/features/trips/data/open_meteo_terrain_risk_provider.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_evidence_provider.dart';

void main() {
  const location = ConnectivityRiskSampleLocation(
    latitude: 21,
    longitude: 105,
    distanceFromStartMeters: 10000,
    progressRatio: 0.1,
  );

  group('OpenMeteoTerrainRiskProvider', () {
    test('exposes stable provider id', () {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [100, 100, 100, 100, 100],
            }),
            200,
          );
        }),
      );

      expect(provider.providerId, 'open-meteo-terrain-proxy');
    });

    test('requests center plus four surrounding coordinates', () async {
      Uri? capturedUri;

      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          capturedUri = request.url;

          return http.Response(
            jsonEncode({
              'elevation': [100, 110, 90, 105, 95],
            }),
            200,
          );
        }),
      );

      await provider.getEvidence(location);

      expect(capturedUri, isNotNull);

      final latitudes = capturedUri!.queryParameters['latitude']!.split(',');
      final longitudes = capturedUri!.queryParameters['longitude']!.split(',');

      expect(latitudes.length, 5);
      expect(longitudes.length, 5);

      expect(double.parse(latitudes.first), closeTo(21, 0.000001));

      expect(double.parse(longitudes.first), closeTo(105, 0.000001));
    });

    test('flat low terrain produces very low terrain risk', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [100, 105, 95, 100, 102],
            }),
            200,
          );
        }),
      );

      final result = await provider.getEvidence(location);

      expect(result.length, 1);

      final evidence = result.single;

      expect(evidence.type, ConnectivityRiskEvidenceType.terrain);

      expect(evidence.riskScore, lessThan(0.05));
      expect(evidence.confidence, 0.55);
      expect(evidence.source, 'open_meteo_copernicus_dem_proxy');
    });

    test('rugged terrain produces high terrain risk', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [900, 1300, 500, 1150, 650],
            }),
            200,
          );
        }),
      );

      final result = await provider.getEvidence(location);
      final evidence = result.single;

      expect(evidence.riskScore, greaterThan(0.8));
      expect(evidence.description, contains('proxy địa hình'));
      expect(evidence.description, contains('không phải dữ liệu phủ sóng'));
    });

    test('high but flat terrain remains moderate proxy risk', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [2000, 2010, 1990, 2005, 1995],
            }),
            200,
          );
        }),
      );

      final evidence = (await provider.getEvidence(location)).single;

      expect(evidence.riskScore, greaterThan(0.05));
      expect(evidence.riskScore, lessThan(0.3));
    });

    test('supports custom risk policy', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [100, 400, 0, 200, 100],
            }),
            200,
          );
        }),
        policy: const TerrainRiskProxyPolicy(
          neighborhoodRadiusMeters: 1000,
          reliefRiskMaxMeters: 400,
          elevationRiskStartMeters: 0,
          elevationRiskMaxMeters: 1000,
          reliefWeight: 1,
          elevationWeight: 0,
          evidenceConfidence: 0.4,
        ),
      );

      final evidence = (await provider.getEvidence(location)).single;

      expect(evidence.riskScore, 1);
      expect(evidence.confidence, 0.4);
      expect(evidence.description, contains('1000 m'));
    });

    test('throws for HTTP error', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response('server error', 500);
        }),
      );

      expect(() => provider.getEvidence(location), throwsException);
    });

    test('throws when elevation array is incomplete', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [100, 110],
            }),
            200,
          );
        }),
      );

      expect(
        () => provider.getEvidence(location),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when elevation contains invalid value', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [100, 110, null, 90, 100],
            }),
            200,
          );
        }),
      );

      expect(
        () => provider.getEvidence(location),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws for invalid proxy policy', () async {
      final provider = OpenMeteoTerrainRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'elevation': [100, 100, 100, 100, 100],
            }),
            200,
          );
        }),
        policy: const TerrainRiskProxyPolicy(reliefRiskMaxMeters: 0),
      );

      expect(() => provider.getEvidence(location), throwsA(isA<StateError>()));
    });
  });
}
