import 'dart:convert';

import 'emergency_readiness.dart';
import 'personal_readiness.dart';
import 'route_weather_readiness.dart';
import 'vehicle_readiness.dart';

class TripReadinessChecklistSnapshot {
  const TripReadinessChecklistSnapshot({
    required this.schemaVersion,
    required this.tripId,
    required this.updatedAt,
    this.routeFingerprint,
    this.vehicle = const VehicleReadinessConfirmations(),
    this.personal = const PersonalReadinessConfirmations(),
    this.routeWeather = const RouteWeatherReadinessConfirmations(),
    this.emergency = const EmergencyReadinessConfirmations(),
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String tripId;
  final DateTime updatedAt;

  /// Dấu vân tay tuyến tại thời điểm người dùng xác nhận phần route/weather.
  /// UI/service sau này có thể dùng để vô hiệu xác nhận tuyến cũ khi route đổi.
  final String? routeFingerprint;

  final VehicleReadinessConfirmations vehicle;
  final PersonalReadinessConfirmations personal;
  final RouteWeatherReadinessConfirmations routeWeather;
  final EmergencyReadinessConfirmations emergency;

  bool get hasAnyConfirmation =>
      vehicle.fuelOrEnergyReady != null ||
      vehicle.mechanicalConditionOk != null ||
      vehicle.tiresOk != null ||
      vehicle.documentsAvailable != null ||
      personal.protectiveGearReady != null ||
      personal.personalEssentialsReady != null ||
      routeWeather.routeReviewed != null ||
      routeWeather.weatherReviewed != null ||
      emergency.emergencyContactsReady != null ||
      emergency.sosPlanReviewed != null ||
      emergency.firstAidKitReady != null;

  bool get isComplete =>
      vehicle.isComplete &&
      personal.isComplete &&
      routeWeather.isComplete &&
      emergency.isComplete;

  TripReadinessChecklistSnapshot copyWith({
    int? schemaVersion,
    String? tripId,
    DateTime? updatedAt,
    String? routeFingerprint,
    bool clearRouteFingerprint = false,
    VehicleReadinessConfirmations? vehicle,
    PersonalReadinessConfirmations? personal,
    RouteWeatherReadinessConfirmations? routeWeather,
    EmergencyReadinessConfirmations? emergency,
  }) {
    return TripReadinessChecklistSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      tripId: tripId ?? this.tripId,
      updatedAt: updatedAt ?? this.updatedAt,
      routeFingerprint: clearRouteFingerprint
          ? null
          : routeFingerprint ?? this.routeFingerprint,
      vehicle: vehicle ?? this.vehicle,
      personal: personal ?? this.personal,
      routeWeather: routeWeather ?? this.routeWeather,
      emergency: emergency ?? this.emergency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'trip_id': tripId.trim(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'route_fingerprint': _nullableTrimmed(routeFingerprint),
      'vehicle': {
        'fuel_or_energy_ready': vehicle.fuelOrEnergyReady,
        'mechanical_condition_ok': vehicle.mechanicalConditionOk,
        'tires_ok': vehicle.tiresOk,
        'documents_available': vehicle.documentsAvailable,
        'checked_at': vehicle.checkedAt?.toUtc().toIso8601String(),
      },
      'personal': {
        'protective_gear_ready': personal.protectiveGearReady,
        'personal_essentials_ready': personal.personalEssentialsReady,
        'checked_at': personal.checkedAt?.toUtc().toIso8601String(),
      },
      'route_weather': {
        'route_reviewed': routeWeather.routeReviewed,
        'weather_reviewed': routeWeather.weatherReviewed,
        'checked_at': routeWeather.checkedAt?.toUtc().toIso8601String(),
      },
      'emergency': {
        'emergency_contacts_ready': emergency.emergencyContactsReady,
        'sos_plan_reviewed': emergency.sosPlanReviewed,
        'first_aid_kit_ready': emergency.firstAidKitReady,
        'checked_at': emergency.checkedAt?.toUtc().toIso8601String(),
      },
    };
  }

  String encode() => jsonEncode(toJson());

  factory TripReadinessChecklistSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(
      json['schema_version'],
      'schema_version',
    );

    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Không hỗ trợ trip readiness schema version $schemaVersion.',
      );
    }

    final tripId = _requiredString(json['trip_id'], 'trip_id');
    final updatedAt = _requiredDateTime(json['updated_at'], 'updated_at');

    final vehicleJson = _map(json['vehicle']);
    final personalJson = _map(json['personal']);
    final routeWeatherJson = _map(json['route_weather']);
    final emergencyJson = _map(json['emergency']);

    return TripReadinessChecklistSnapshot(
      schemaVersion: schemaVersion,
      tripId: tripId,
      updatedAt: updatedAt,
      routeFingerprint: _optionalString(json['route_fingerprint']),
      vehicle: VehicleReadinessConfirmations(
        fuelOrEnergyReady: _optionalBool(vehicleJson['fuel_or_energy_ready']),
        mechanicalConditionOk: _optionalBool(
          vehicleJson['mechanical_condition_ok'],
        ),
        tiresOk: _optionalBool(vehicleJson['tires_ok']),
        documentsAvailable: _optionalBool(vehicleJson['documents_available']),
        checkedAt: _optionalDateTime(vehicleJson['checked_at']),
      ),
      personal: PersonalReadinessConfirmations(
        protectiveGearReady: _optionalBool(
          personalJson['protective_gear_ready'],
        ),
        personalEssentialsReady: _optionalBool(
          personalJson['personal_essentials_ready'],
        ),
        checkedAt: _optionalDateTime(personalJson['checked_at']),
      ),
      routeWeather: RouteWeatherReadinessConfirmations(
        routeReviewed: _optionalBool(routeWeatherJson['route_reviewed']),
        weatherReviewed: _optionalBool(routeWeatherJson['weather_reviewed']),
        checkedAt: _optionalDateTime(routeWeatherJson['checked_at']),
      ),
      emergency: EmergencyReadinessConfirmations(
        emergencyContactsReady: _optionalBool(
          emergencyJson['emergency_contacts_ready'],
        ),
        sosPlanReviewed: _optionalBool(emergencyJson['sos_plan_reviewed']),
        firstAidKitReady: _optionalBool(emergencyJson['first_aid_kit_ready']),
        checkedAt: _optionalDateTime(emergencyJson['checked_at']),
      ),
    );
  }

  factory TripReadinessChecklistSnapshot.decode(String encoded) {
    final decoded = jsonDecode(encoded);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Trip readiness snapshot JSON không hợp lệ.');
    }

    return TripReadinessChecklistSnapshot.fromJson(decoded);
  }

  static TripReadinessChecklistSnapshot empty({
    required String tripId,
    DateTime? updatedAt,
  }) {
    final normalizedTripId = tripId.trim();

    if (normalizedTripId.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    return TripReadinessChecklistSnapshot(
      schemaVersion: currentSchemaVersion,
      tripId: normalizedTripId,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value == null) {
    return const <String, dynamic>{};
  }

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, dynamic item) => MapEntry(key.toString(), item));
  }

  throw const FormatException(
    'Trip readiness snapshot chứa object không hợp lệ.',
  );
}

int _requiredInt(dynamic value, String field) {
  if (value is int) {
    return value;
  }

  if (value is num && value.toInt() == value) {
    return value.toInt();
  }

  throw FormatException('$field không hợp lệ.');
}

String _requiredString(dynamic value, String field) {
  final result = value is String ? value.trim() : '';

  if (result.isEmpty) {
    throw FormatException('$field không được rỗng.');
  }

  return result;
}

String? _optionalString(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw const FormatException('Giá trị chuỗi tùy chọn không hợp lệ.');
  }

  final result = value.trim();
  return result.isEmpty ? null : result;
}

String? _nullableTrimmed(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}

bool? _optionalBool(dynamic value) {
  if (value == null || value is bool) {
    return value as bool?;
  }

  throw const FormatException('Giá trị boolean tùy chọn không hợp lệ.');
}

DateTime _requiredDateTime(dynamic value, String field) {
  final result = _optionalDateTime(value);

  if (result == null) {
    throw FormatException('$field không hợp lệ.');
  }

  return result;
}

DateTime? _optionalDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Giá trị thời gian không hợp lệ.');
  }

  final parsed = DateTime.tryParse(value.trim());

  if (parsed == null) {
    throw const FormatException('Giá trị thời gian không hợp lệ.');
  }

  return parsed.toUtc();
}
