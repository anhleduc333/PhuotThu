import '../domain/place_result.dart';

abstract class PlaceSearchService {
  Future<List<PlaceResult>> searchPlaces(String query);
}
