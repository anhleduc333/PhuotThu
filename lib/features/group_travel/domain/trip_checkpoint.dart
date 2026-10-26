/// Checkpoint data model for DEV-09.7. Dates from Supabase are normalized to UTC.
class TripCheckpoint {
  const TripCheckpoint({
    required this.id,
    required this.tripId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.sortOrder,
    required this.isRequired,
    required this.autoArrivalEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.note,
    this.plannedAt,
  });

  final String id;
  final String tripId;
  final String? createdBy;
  final String name;
  final String? note;
  final double latitude;
  final double longitude;
  final int radiusM;
  final int sortOrder;
  final DateTime? plannedAt;
  final bool isRequired;
  final bool autoArrivalEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TripCheckpoint.fromJson(Map<String, dynamic> json) {
    final name = _checkpointRequiredString(json['name'], 'name');
    final latitude = _checkpointRequiredDouble(json['latitude'], 'latitude');
    final longitude = _checkpointRequiredDouble(json['longitude'], 'longitude');
    final radiusM = _checkpointRequiredInt(json['radius_m'], 'radius_m');
    final sortOrder = _checkpointRequiredInt(json['sort_order'], 'sort_order');

    if (name.length > 120 ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        radiusM < 10 ||
        radiusM > 5000 ||
        sortOrder < 0) {
      throw const FormatException(
        'Checkpoint có giá trị ngoài phạm vi cho phép.',
      );
    }

    return TripCheckpoint(
      id: _checkpointRequiredString(json['id'], 'id'),
      tripId: _checkpointRequiredString(json['trip_id'], 'trip_id'),
      createdBy: _checkpointOptionalString(json['created_by'], 'created_by'),
      name: name,
      note: _checkpointOptionalString(json['note'], 'note'),
      latitude: latitude,
      longitude: longitude,
      radiusM: radiusM,
      sortOrder: sortOrder,
      plannedAt: _checkpointOptionalDate(json['planned_at'], 'planned_at'),
      isRequired: _checkpointRequiredBool(json['is_required'], 'is_required'),
      autoArrivalEnabled: _checkpointRequiredBool(
        json['auto_arrival_enabled'],
        'auto_arrival_enabled',
      ),
      createdAt: _checkpointRequiredDate(json['created_at'], 'created_at'),
      updatedAt: _checkpointRequiredDate(json['updated_at'], 'updated_at'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'created_by': createdBy,
    'name': name,
    'note': note,
    'latitude': latitude,
    'longitude': longitude,
    'radius_m': radiusM,
    'sort_order': sortOrder,
    'planned_at': plannedAt?.toUtc().toIso8601String(),
    'is_required': isRequired,
    'auto_arrival_enabled': autoArrivalEnabled,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

String _checkpointRequiredString(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }
  return value.trim();
}

String? _checkpointOptionalString(dynamic value, String field) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$field không hợp lệ.');
  return value;
}

double _checkpointRequiredDouble(dynamic value, String field) {
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$field không hợp lệ.');
  }
  return value.toDouble();
}

int _checkpointRequiredInt(dynamic value, String field) {
  if (value is! int) throw FormatException('$field không hợp lệ.');
  return value;
}

bool _checkpointRequiredBool(dynamic value, String field) {
  if (value is! bool) throw FormatException('$field không hợp lệ.');
  return value;
}

DateTime _checkpointRequiredDate(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$field không hợp lệ.');
  return parsed.toUtc();
}

DateTime? _checkpointOptionalDate(dynamic value, String field) {
  if (value == null) return null;
  return _checkpointRequiredDate(value, field);
}
