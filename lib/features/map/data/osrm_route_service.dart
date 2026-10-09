import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/route_result.dart';
import 'route_service.dart';

class OsrmRouteService implements RouteService {
  OsrmRouteService(this._client);

  final http.Client _client;

  @override
  Future<RouteResult> getRoute({
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final coordinates =
        '$startLongitude,$startLatitude;'
        '$destinationLongitude,$destinationLatitude';

    final uri =
        Uri.parse(
          'https://router.project-osrm.org/'
          'route/v1/driving/$coordinates',
        ).replace(
          queryParameters: const {
            'alternatives': 'false',
            'steps': 'false',
            'overview': 'full',
            'geometries': 'geojson',
          },
        );

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'PhuotThu/0.1 (com.anhleduc333.phuotthu)',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('OSRM HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid OSRM response');
    }

    if (decoded['code'] != 'Ok') {
      throw StateError(
        decoded['message']?.toString() ?? 'Không tìm thấy tuyến đường.',
      );
    }

    final routes = decoded['routes'];

    if (routes is! List || routes.isEmpty) {
      throw StateError('OSRM không trả về tuyến đường.');
    }

    final route = Map<String, dynamic>.from(routes.first as Map);

    final geometry = route['geometry'];

    if (geometry is! Map) {
      throw const FormatException('Route geometry is missing');
    }

    final coordinatesJson = geometry['coordinates'];

    if (coordinatesJson is! List || coordinatesJson.isEmpty) {
      throw const FormatException('Route coordinates are missing');
    }

    final points = <RoutePoint>[];

    for (final coordinate in coordinatesJson) {
      if (coordinate is! List || coordinate.length < 2) {
        continue;
      }

      final longitude = (coordinate[0] as num).toDouble();

      final latitude = (coordinate[1] as num).toDouble();

      points.add(RoutePoint(latitude: latitude, longitude: longitude));
    }

    if (points.length < 2) {
      throw const FormatException('Route does not contain enough points');
    }

    final distance = (route['distance'] as num).round();

    final duration = (route['duration'] as num).round();

    return RouteResult(
      distanceMeters: distance,
      durationSeconds: duration,
      points: points,
    );
  }
}
