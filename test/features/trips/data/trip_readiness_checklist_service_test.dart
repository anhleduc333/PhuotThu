import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/data/trip_readiness_checklist_repository.dart';
import 'package:phuotthu/features/trips/data/trip_readiness_checklist_service.dart';
import 'package:phuotthu/features/trips/domain/emergency_readiness.dart';
import 'package:phuotthu/features/trips/domain/personal_readiness.dart';
import 'package:phuotthu/features/trips/domain/route_weather_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness_checklist_snapshot.dart';
import 'package:phuotthu/features/trips/domain/vehicle_readiness.dart';

class MemoryRepository implements TripReadinessChecklistRepository {
  final Map<String, TripReadinessChecklistSnapshot> values = {};

  @override
  Future<bool> exists(String tripId) async => values.containsKey(tripId);

  @override
  Future<TripReadinessChecklistSnapshot?> load(String tripId) async =>
      values[tripId];

  @override
  Future<void> remove(String tripId) async {
    values.remove(tripId);
  }

  @override
  Future<void> save(TripReadinessChecklistSnapshot snapshot) async {
    values[snapshot.tripId] = snapshot;
  }
}

void main() {
  late MemoryRepository repository;
  late TripReadinessChecklistService service;

  setUp(() {
    repository = MemoryRepository();
    service = TripReadinessChecklistService(repository: repository);
  });

  test('loadOrCreate returns empty snapshot for new trip', () async {
    final result = await service.loadOrCreate('trip-1');

    expect(result.tripId, 'trip-1');
    expect(result.hasAnyConfirmation, isFalse);
  });

  test('category saves preserve other category confirmations', () async {
    await service.saveVehicle(
      tripId: 'trip-1',
      confirmations: const VehicleReadinessConfirmations(
        fuelOrEnergyReady: true,
      ),
      updatedAt: DateTime.utc(2026, 10, 25, 1),
    );

    await service.savePersonal(
      tripId: 'trip-1',
      confirmations: const PersonalReadinessConfirmations(
        protectiveGearReady: true,
      ),
      updatedAt: DateTime.utc(2026, 10, 25, 2),
    );

    final result = await service.loadOrCreate('trip-1');

    expect(result.vehicle.fuelOrEnergyReady, isTrue);
    expect(result.personal.protectiveGearReady, isTrue);
    expect(result.updatedAt, DateTime.utc(2026, 10, 25, 2));
  });

  test('route save persists fingerprint', () async {
    final result = await service.saveRouteWeather(
      tripId: 'trip-1',
      confirmations: const RouteWeatherReadinessConfirmations(
        routeReviewed: true,
      ),
      routeFingerprint: 'route-v1',
      updatedAt: DateTime.utc(2026, 10, 25),
    );

    expect(result.routeFingerprint, 'route-v1');
    expect(result.routeWeather.routeReviewed, isTrue);
  });

  test('route save clears blank fingerprint', () async {
    await service.saveRouteWeather(
      tripId: 'trip-1',
      confirmations: const RouteWeatherReadinessConfirmations(
        routeReviewed: true,
      ),
      routeFingerprint: 'route-v1',
    );

    final result = await service.saveRouteWeather(
      tripId: 'trip-1',
      confirmations: const RouteWeatherReadinessConfirmations(
        routeReviewed: false,
      ),
      routeFingerprint: '   ',
    );

    expect(result.routeFingerprint, isNull);
  });

  test('emergency confirmations persist', () async {
    final result = await service.saveEmergency(
      tripId: 'trip-1',
      confirmations: const EmergencyReadinessConfirmations(
        emergencyContactsReady: true,
        sosPlanReviewed: true,
        firstAidKitReady: false,
      ),
      updatedAt: DateTime.utc(2026, 10, 25),
    );

    expect(result.emergency.emergencyContactsReady, isTrue);
    expect(result.emergency.firstAidKitReady, isFalse);
  });

  test('remove deletes persisted checklist', () async {
    await service.savePersonal(
      tripId: 'trip-1',
      confirmations: const PersonalReadinessConfirmations(
        protectiveGearReady: true,
      ),
    );

    await service.remove('trip-1');

    expect(await repository.exists('trip-1'), isFalse);
  });
}
