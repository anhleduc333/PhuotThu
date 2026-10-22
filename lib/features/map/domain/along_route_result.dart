import 'along_route_place.dart';

class AlongRouteResult {
  const AlongRouteResult({
    required this.places,
    required this.provider,
    required this.searchedPointCount,
  });

  final List<AlongRoutePlace> places;

  /// Provider đã thực hiện truy vấn.
  ///
  /// Ví dụ:
  /// overpass
  /// google_places
  final String provider;

  /// Số điểm trên tuyến được dùng làm điểm mẫu tìm kiếm.
  ///
  /// Không truy vấn từng điểm của polyline vì tuyến dài
  /// có thể chứa hàng nghìn điểm.
  final int searchedPointCount;

  bool get isEmpty => places.isEmpty;

  int get count => places.length;
}
