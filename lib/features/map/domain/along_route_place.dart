enum AlongRoutePlaceType { fuel, restArea, food, repair, medical }

extension AlongRoutePlaceTypeX on AlongRoutePlaceType {
  String get key {
    switch (this) {
      case AlongRoutePlaceType.fuel:
        return 'fuel';
      case AlongRoutePlaceType.restArea:
        return 'rest_area';
      case AlongRoutePlaceType.food:
        return 'food';
      case AlongRoutePlaceType.repair:
        return 'repair';
      case AlongRoutePlaceType.medical:
        return 'medical';
    }
  }

  String get label {
    switch (this) {
      case AlongRoutePlaceType.fuel:
        return 'Cây xăng';
      case AlongRoutePlaceType.restArea:
        return 'Điểm nghỉ';
      case AlongRoutePlaceType.food:
        return 'Ăn uống';
      case AlongRoutePlaceType.repair:
        return 'Sửa chữa';
      case AlongRoutePlaceType.medical:
        return 'Y tế';
    }
  }
}

class AlongRoutePlace {
  const AlongRoutePlace({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.sourceId,
    this.address,
    this.openingHours,
    this.phone,
    this.website,
    this.distanceFromRouteMeters,
    this.tags = const {},
  });

  final String id;

  final String name;

  final AlongRoutePlaceType type;

  final double latitude;
  final double longitude;

  final String source;
  final String sourceId;

  final String? address;
  final String? openingHours;
  final String? phone;
  final String? website;

  /// Khoảng cách gần nhất từ POI tới tuyến đường.
  ///
  /// Giá trị này sẽ được tính phía ứng dụng sau khi
  /// nhận dữ liệu từ provider.
  final double? distanceFromRouteMeters;

  /// Giữ lại các tag gốc hữu ích từ provider.
  ///
  /// Không nên phụ thuộc trực tiếp vào tags trong UI.
  final Map<String, String> tags;

  AlongRoutePlace copyWith({
    String? id,
    String? name,
    AlongRoutePlaceType? type,
    double? latitude,
    double? longitude,
    String? source,
    String? sourceId,
    String? address,
    String? openingHours,
    String? phone,
    String? website,
    double? distanceFromRouteMeters,
    Map<String, String>? tags,
  }) {
    return AlongRoutePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      address: address ?? this.address,
      openingHours: openingHours ?? this.openingHours,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      distanceFromRouteMeters:
          distanceFromRouteMeters ?? this.distanceFromRouteMeters,
      tags: tags ?? this.tags,
    );
  }
}
