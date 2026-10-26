/// Inputs intentionally omit user_id/created_by and GPS arrival fields.
/// The DB owns creator attribution and manual-arrival timestamps.
class CreateTripCheckpointInput {
  const CreateTripCheckpointInput({
    required this.tripId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.note,
    this.radiusM = 100,
    this.sortOrder = 0,
    this.plannedAt,
    this.isRequired = true,
    this.autoArrivalEnabled = true,
  });

  final String tripId;
  final String name;
  final String? note;
  final double latitude;
  final double longitude;
  final int radiusM;
  final int sortOrder;
  final DateTime? plannedAt;
  final bool isRequired;
  final bool autoArrivalEnabled;

  bool get isValid =>
      tripId.trim().isNotEmpty &&
      name.trim().isNotEmpty &&
      name.trim().length <= 120 &&
      latitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude.isFinite &&
      longitude >= -180 &&
      longitude <= 180 &&
      radiusM >= 10 &&
      radiusM <= 5000 &&
      sortOrder >= 0;

  Map<String, dynamic> toInsertJson() {
    if (!isValid) throw StateError('Dữ liệu tạo checkpoint không hợp lệ.');
    return {
      'trip_id': tripId.trim(),
      'name': name.trim(),
      'note': note?.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radius_m': radiusM,
      'sort_order': sortOrder,
      'planned_at': plannedAt?.toUtc().toIso8601String(),
      'is_required': isRequired,
      'auto_arrival_enabled': autoArrivalEnabled,
    };
  }
}

/// Null means unchanged; use clearNote/clearPlannedAt to explicitly send NULL.
class UpdateTripCheckpointInput {
  const UpdateTripCheckpointInput({
    this.name,
    this.note,
    this.clearNote = false,
    this.latitude,
    this.longitude,
    this.radiusM,
    this.sortOrder,
    this.plannedAt,
    this.clearPlannedAt = false,
    this.isRequired,
    this.autoArrivalEnabled,
  });

  final String? name;
  final String? note;
  final bool clearNote;
  final double? latitude;
  final double? longitude;
  final int? radiusM;
  final int? sortOrder;
  final DateTime? plannedAt;
  final bool clearPlannedAt;
  final bool? isRequired;
  final bool? autoArrivalEnabled;

  bool get isValid =>
      !(clearNote && note != null) &&
      !(clearPlannedAt && plannedAt != null) &&
      (name == null ||
          (name!.trim().isNotEmpty && name!.trim().length <= 120)) &&
      (latitude == null ||
          (latitude!.isFinite && latitude! >= -90 && latitude! <= 90)) &&
      (longitude == null ||
          (longitude!.isFinite && longitude! >= -180 && longitude! <= 180)) &&
      (radiusM == null || (radiusM! >= 10 && radiusM! <= 5000)) &&
      (sortOrder == null || sortOrder! >= 0);

  Map<String, dynamic> toUpdateJson() {
    if (!isValid) throw StateError('Dữ liệu cập nhật checkpoint không hợp lệ.');
    final changes = <String, dynamic>{};
    if (name != null) changes['name'] = name!.trim();
    if (clearNote) {
      changes['note'] = null;
    } else if (note != null) {
      changes['note'] = note!.trim();
    }
    if (latitude != null) changes['latitude'] = latitude;
    if (longitude != null) changes['longitude'] = longitude;
    if (radiusM != null) changes['radius_m'] = radiusM;
    if (sortOrder != null) changes['sort_order'] = sortOrder;
    if (clearPlannedAt) {
      changes['planned_at'] = null;
    } else if (plannedAt != null) {
      changes['planned_at'] = plannedAt!.toUtc().toIso8601String();
    }
    if (isRequired != null) changes['is_required'] = isRequired;
    if (autoArrivalEnabled != null) {
      changes['auto_arrival_enabled'] = autoArrivalEnabled;
    }
    if (changes.isEmpty) {
      throw StateError('Không có trường checkpoint nào cần cập nhật.');
    }
    return changes;
  }
}
