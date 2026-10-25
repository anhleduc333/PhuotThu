import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/emergency_readiness.dart';
import 'package:phuotthu/features/trips/domain/personal_readiness.dart';
import 'package:phuotthu/features/trips/domain/route_weather_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness_checklist_snapshot.dart';
import 'package:phuotthu/features/trips/domain/vehicle_readiness.dart';

void main() {
  TripReadinessChecklistSnapshot sample() {
    return TripReadinessChecklistSnapshot(
      schemaVersion: TripReadinessChecklistSnapshot.currentSchemaVersion,
      tripId: 'trip-1',
      updatedAt: DateTime.parse('2026-10-25T15:00:00+07:00'),
      routeFingerprint: ' route-v1 ',
      vehicle: VehicleReadinessConfirmations(
        fuelOrEnergyReady: true,
        mechanicalConditionOk: false,
        tiresOk: true,
        documentsAvailable: true,
        checkedAt: DateTime.parse('2026-10-25T14:00:00+07:00'),
      ),
      personal: const PersonalReadinessConfirmations(
        protectiveGearReady: true,
        personalEssentialsReady: false,
      ),
      routeWeather: const RouteWeatherReadinessConfirmations(
        routeReviewed: true,
        weatherReviewed: true,
      ),
      emergency: const EmergencyReadinessConfirmations(
        emergencyContactsReady: true,
        sosPlanReviewed: true,
        firstAidKitReady: false,
      ),
    );
  }

  test('round trips all confirmations through JSON', () {
    final decoded = TripReadinessChecklistSnapshot.decode(sample().encode());

    expect(decoded.tripId, 'trip-1');
    expect(decoded.routeFingerprint, 'route-v1');
    expect(decoded.vehicle.fuelOrEnergyReady, isTrue);
    expect(decoded.vehicle.mechanicalConditionOk, isFalse);
    expect(decoded.personal.personalEssentialsReady, isFalse);
    expect(decoded.routeWeather.weatherReviewed, isTrue);
    expect(decoded.emergency.firstAidKitReady, isFalse);
  });

  test('normalizes timestamps to UTC during serialization', () {
    final decoded = TripReadinessChecklistSnapshot.decode(sample().encode());

    expect(decoded.updatedAt.isUtc, isTrue);
    expect(decoded.updatedAt.hour, 8);
    expect(decoded.vehicle.checkedAt!.isUtc, isTrue);
    expect(decoded.vehicle.checkedAt!.hour, 7);
  });

  test('empty snapshot has no confirmations', () {
    final snapshot = TripReadinessChecklistSnapshot.empty(
      tripId: ' trip-2 ',
      updatedAt: DateTime.utc(2026, 10, 25),
    );

    expect(snapshot.tripId, 'trip-2');
    expect(snapshot.hasAnyConfirmation, isFalse);
    expect(snapshot.isComplete, isFalse);
  });

  test('complete snapshot reports complete', () {
    final complete = TripReadinessChecklistSnapshot(
      schemaVersion: 1,
      tripId: 'trip-1',
      updatedAt: DateTime.utc(2026, 10, 25),
      vehicle: const VehicleReadinessConfirmations(
        fuelOrEnergyReady: true,
        mechanicalConditionOk: true,
        tiresOk: true,
        documentsAvailable: true,
      ),
      personal: const PersonalReadinessConfirmations(
        protectiveGearReady: true,
        personalEssentialsReady: true,
      ),
      routeWeather: const RouteWeatherReadinessConfirmations(
        routeReviewed: true,
        weatherReviewed: true,
      ),
      emergency: const EmergencyReadinessConfirmations(
        emergencyContactsReady: true,
        sosPlanReviewed: true,
        firstAidKitReady: true,
      ),
    );

    expect(complete.hasAnyConfirmation, isTrue);
    expect(complete.isComplete, isTrue);
  });

  test('copyWith can replace and clear route fingerprint', () {
    final initial = sample();

    final replaced = initial.copyWith(routeFingerprint: 'route-v2');

    final cleared = replaced.copyWith(clearRouteFingerprint: true);

    expect(replaced.routeFingerprint, 'route-v2');
    expect(cleared.routeFingerprint, isNull);
  });

  test('rejects unsupported schema version', () {
    final json = sample().toJson();
    json['schema_version'] = 99;

    expect(
      () => TripReadinessChecklistSnapshot.fromJson(json),
      throwsFormatException,
    );
  });

  test('rejects blank trip id', () {
    expect(
      () => TripReadinessChecklistSnapshot.empty(tripId: '   '),
      throwsArgumentError,
    );
  });

  test('rejects malformed JSON', () {
    expect(
      () => TripReadinessChecklistSnapshot.decode('{bad json'),
      throwsA(anything),
    );
  });
}
