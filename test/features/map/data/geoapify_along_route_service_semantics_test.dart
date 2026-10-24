import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:phuotthu/features/map/data/geoapify_along_route_service.dart';
import 'package:phuotthu/features/map/domain/along_route_place.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';

void main() {
  List<RoutePoint> route() => const [
    RoutePoint(latitude: 0, longitude: 0),
    RoutePoint(latitude: 0, longitude: 1),
  ];

  group('GeoapifyAlongRouteService semantics', () {
    test('restArea searches lodging categories instead of picnic', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeoapifyAlongRouteService(
        client,
        apiKey: 'test-key',
        endpoint: Uri.parse('https://example.com/places'),
      );

      await service.search(
        routePoints: route(),
        types: const {AlongRoutePlaceType.restArea},
        maxResults: 20,
      );

      expect(bodies, hasLength(1));
      expect((bodies.single['categories'] as List).toSet(), {
        'accommodation.hotel',
        'accommodation.guest_house',
        'accommodation.motel',
        'accommodation.hostel',
      });
      expect(bodies.single['categories'], isNot(contains('leisure.picnic')));
    });

    test('food search is balanced into eating and drinking batches', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeoapifyAlongRouteService(
        client,
        apiKey: 'test-key',
        endpoint: Uri.parse('https://example.com/places'),
      );

      await service.search(
        routePoints: route(),
        types: const {AlongRoutePlaceType.food},
        maxResults: 20,
      );

      expect(bodies, hasLength(2));

      final categorySets = bodies
          .map((body) => (body['categories'] as List).toSet())
          .toList();

      expect(
        categorySets.any(
          (categories) =>
              categories.contains('catering.restaurant') &&
              categories.contains('catering.fast_food') &&
              categories.contains('catering.food_court'),
        ),
        isTrue,
      );
      expect(
        categorySets.any(
          (categories) =>
              categories.contains('catering.cafe') &&
              categories.contains('catering.bar') &&
              categories.contains('catering.pub') &&
              categories.contains('catering.biergarten'),
        ),
        isTrue,
      );
    });

    test('fuel keeps the existing fuel category', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GeoapifyAlongRouteService(
        client,
        apiKey: 'test-key',
        endpoint: Uri.parse('https://example.com/places'),
      );

      await service.search(
        routePoints: route(),
        types: const {AlongRoutePlaceType.fuel},
        maxResults: 20,
      );

      expect(bodies, hasLength(1));
      expect(bodies.single['categories'], ['service.vehicle.fuel']);
    });
  });
}
