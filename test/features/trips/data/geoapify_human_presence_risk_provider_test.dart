import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phuotthu/features/trips/data/geoapify_human_presence_risk_provider.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_evidence_provider.dart';

void main() {
  const location = ConnectivityRiskSampleLocation(
    latitude: 21,
    longitude: 105,
    distanceFromStartMeters: 10000,
    progressRatio: 0.1,
  );

  Map<String, dynamic> feature({
    required String id,
    required double latitude,
    required double longitude,
  }) {
    return {
      'type': 'Feature',
      'id': id,
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'properties': {'place_id': id, 'name': id},
    };
  }

  group('GeoapifyHumanPresenceRiskProvider', () {
    test('exposes stable provider id', () {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(jsonEncode({'features': []}), 200);
        }),
        apiKey: 'test-key',
      );

      expect(provider.providerId, 'geoapify-human-presence-proxy');
    });

    test('sends circle filter and proximity bias', () async {
      Map<String, dynamic>? capturedBody;
      Map<String, String>? capturedHeaders;

      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          capturedBody = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          capturedHeaders = request.headers;

          return http.Response(jsonEncode({'features': []}), 200);
        }),
        apiKey: 'test-key',
      );

      await provider.getEvidence(location);

      expect(capturedBody, isNotNull);
      expect(capturedHeaders, isNotNull);

      final filter = Map<String, dynamic>.from(capturedBody!['filter'] as Map);
      final bias = Map<String, dynamic>.from(capturedBody!['bias'] as Map);

      expect(filter['type'], 'circle');
      expect(filter['lat'], 21);
      expect(filter['lon'], 105);
      expect(filter['radius'], 5000);

      expect(bias['type'], 'proximity');
      expect(bias['lat'], 21);
      expect(bias['lon'], 105);

      expect(capturedHeaders!['x-api-key'], 'test-key');

      final categories = (capturedBody!['categories'] as List).cast<String>();

      expect(categories, contains('populated_place'));
      expect(categories, contains('catering'));
      expect(categories, contains('healthcare'));
      expect(categories, contains('service.vehicle.fuel'));
    });

    test('empty area produces maximum proxy risks', () async {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(jsonEncode({'features': []}), 200);
        }),
        apiKey: 'test-key',
      );

      final result = await provider.getEvidence(location);

      expect(result.length, 2);

      final settlement = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.settlementDensity,
      );

      final isolation = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.roadIsolation,
      );

      expect(settlement.riskScore, 1);
      expect(isolation.riskScore, 1);

      expect(settlement.confidence, 0.45);
      expect(isolation.confidence, 0.45);

      expect(isolation.description, contains('không tìm thấy POI'));
    });

    test('dense nearby POIs produce low settlement risk', () async {
      final features = List.generate(
        25,
        (index) => feature(
          id: 'p$index',
          latitude: 21,
          longitude: 105 + index * 0.0001,
        ),
      );

      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(jsonEncode({'features': features}), 200);
        }),
        apiKey: 'test-key',
      );

      final result = await provider.getEvidence(location);

      final settlement = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.settlementDensity,
      );

      expect(settlement.riskScore, 0);
      expect(settlement.description, contains('25 POI'));
    });

    test('few nearby POIs produce high settlement risk', () async {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [
                feature(id: 'a', latitude: 21, longitude: 105.001),
                feature(id: 'b', latitude: 21, longitude: 105.002),
                feature(id: 'c', latitude: 21, longitude: 105.003),
              ],
            }),
            200,
          );
        }),
        apiKey: 'test-key',
      );

      final result = await provider.getEvidence(location);

      final settlement = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.settlementDensity,
      );

      expect(settlement.riskScore, closeTo(0.88, 0.0001));
    });

    test('nearby POI produces low road isolation risk', () async {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [
                feature(id: 'near', latitude: 21, longitude: 105.001),
              ],
            }),
            200,
          );
        }),
        apiKey: 'test-key',
      );

      final result = await provider.getEvidence(location);

      final isolation = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.roadIsolation,
      );

      expect(isolation.riskScore, 0);
      expect(isolation.description, contains('POI gần nhất'));
    });

    test('far POI produces high road isolation risk', () async {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [feature(id: 'far', latitude: 21, longitude: 105.04)],
            }),
            200,
          );
        }),
        apiKey: 'test-key',
      );

      final result = await provider.getEvidence(location);

      final isolation = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.roadIsolation,
      );

      expect(isolation.riskScore, greaterThan(0.7));
      expect(isolation.riskScore, lessThanOrEqualTo(1));
    });

    test('deduplicates repeated place ids', () async {
      final repeated = feature(id: 'same', latitude: 21, longitude: 105.001);

      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [
                repeated,
                repeated,
                feature(id: 'other', latitude: 21, longitude: 105.002),
              ],
            }),
            200,
          );
        }),
        apiKey: 'test-key',
        policy: const HumanPresenceRiskProxyPolicy(densePresenceCount: 2),
      );

      final result = await provider.getEvidence(location);

      final settlement = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.settlementDensity,
      );

      expect(settlement.riskScore, 0);
      expect(settlement.description, contains('2 POI'));
    });

    test('ignores invalid or outside-radius features', () async {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'type': 'Feature',
                  'id': 'invalid',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': ['bad', 21],
                  },
                  'properties': {},
                },
                feature(id: 'outside', latitude: 21, longitude: 105.2),
              ],
            }),
            200,
          );
        }),
        apiKey: 'test-key',
      );

      final result = await provider.getEvidence(location);

      final settlement = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.settlementDensity,
      );

      expect(settlement.riskScore, 1);
    });

    test('supports custom policy', () async {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [feature(id: 'one', latitude: 21, longitude: 105.01)],
            }),
            200,
          );
        }),
        apiKey: 'test-key',
        policy: const HumanPresenceRiskProxyPolicy(
          searchRadiusMeters: 3000,
          densePresenceCount: 10,
          isolationSafeDistanceMeters: 0,
          isolationMaxDistanceMeters: 3000,
          settlementEvidenceConfidence: 0.3,
          roadIsolationEvidenceConfidence: 0.35,
        ),
      );

      final result = await provider.getEvidence(location);

      final settlement = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.settlementDensity,
      );
      final isolation = result.singleWhere(
        (item) => item.type == ConnectivityRiskEvidenceType.roadIsolation,
      );

      expect(settlement.riskScore, closeTo(0.9, 0.0001));
      expect(settlement.confidence, 0.3);
      expect(isolation.confidence, 0.35);
    });

    test('throws when API key is missing', () {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(jsonEncode({'features': []}), 200);
        }),
        apiKey: '   ',
      );

      expect(() => provider.getEvidence(location), throwsA(isA<StateError>()));
    });

    test('throws for invalid proxy policy', () {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(jsonEncode({'features': []}), 200);
        }),
        apiKey: 'test-key',
        policy: const HumanPresenceRiskProxyPolicy(densePresenceCount: 0),
      );

      expect(() => provider.getEvidence(location), throwsA(isA<StateError>()));
    });

    test('throws for HTTP error', () {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response('server error', 500);
        }),
        apiKey: 'test-key',
      );

      expect(() => provider.getEvidence(location), throwsException);
    });

    test('throws for malformed response', () {
      final provider = GeoapifyHumanPresenceRiskProvider(
        MockClient((request) async {
          return http.Response(jsonEncode({'unexpected': []}), 200);
        }),
        apiKey: 'test-key',
      );

      expect(
        () => provider.getEvidence(location),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
