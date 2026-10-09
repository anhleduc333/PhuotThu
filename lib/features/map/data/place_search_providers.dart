import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'nominatim_place_search_service.dart';
import 'place_search_service.dart';

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) {
  final client = http.Client();

  ref.onDispose(client.close);

  return NominatimPlaceSearchService(client);
});
