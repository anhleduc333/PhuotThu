class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.provider,
    required this.providerPlaceId,
    this.category,
    this.type,
  });

  final String id;
  final String name;
  final String displayName;

  final double latitude;
  final double longitude;

  final String provider;
  final String providerPlaceId;

  final String? category;
  final String? type;

  factory PlaceResult.fromNominatimMap(Map<String, dynamic> map) {
    final displayName = map['display_name']?.toString().trim() ?? '';

    final rawName = map['name']?.toString().trim();

    final name = rawName != null && rawName.isNotEmpty
        ? rawName
        : displayName.split(',').first.trim();

    final placeId = map['place_id']?.toString() ?? '';

    final latitude = double.parse(map['lat'].toString());

    final longitude = double.parse(map['lon'].toString());

    return PlaceResult(
      id: 'nominatim:$placeId',
      name: name.isEmpty ? displayName : name,
      displayName: displayName,
      latitude: latitude,
      longitude: longitude,
      provider: 'nominatim',
      providerPlaceId: placeId,
      category: map['category']?.toString() ?? map['class']?.toString(),
      type: map['type']?.toString(),
    );
  }
}
