import '../domain/emergency_readiness.dart';
import '../domain/personal_readiness.dart';
import '../domain/route_weather_readiness.dart';
import '../domain/trip_readiness_checklist_snapshot.dart';
import '../domain/vehicle_readiness.dart';
import 'trip_readiness_checklist_repository.dart';

class TripReadinessChecklistService {
  const TripReadinessChecklistService({required this.repository});

  final TripReadinessChecklistRepository repository;

  Future<TripReadinessChecklistSnapshot> loadOrCreate(String tripId) async {
    final existing = await repository.load(tripId);

    return existing ?? TripReadinessChecklistSnapshot.empty(tripId: tripId);
  }

  Future<TripReadinessChecklistSnapshot> saveVehicle({
    required String tripId,
    required VehicleReadinessConfirmations confirmations,
    DateTime? updatedAt,
  }) async {
    final current = await loadOrCreate(tripId);

    final snapshot = current.copyWith(
      vehicle: confirmations,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );

    await repository.save(snapshot);
    return snapshot;
  }

  Future<TripReadinessChecklistSnapshot> savePersonal({
    required String tripId,
    required PersonalReadinessConfirmations confirmations,
    DateTime? updatedAt,
  }) async {
    final current = await loadOrCreate(tripId);

    final snapshot = current.copyWith(
      personal: confirmations,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );

    await repository.save(snapshot);
    return snapshot;
  }

  Future<TripReadinessChecklistSnapshot> saveRouteWeather({
    required String tripId,
    required RouteWeatherReadinessConfirmations confirmations,
    String? routeFingerprint,
    DateTime? updatedAt,
  }) async {
    final current = await loadOrCreate(tripId);

    final snapshot = current.copyWith(
      routeWeather: confirmations,
      routeFingerprint: routeFingerprint,
      clearRouteFingerprint:
          routeFingerprint == null || routeFingerprint.trim().isEmpty,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );

    await repository.save(snapshot);
    return snapshot;
  }

  Future<TripReadinessChecklistSnapshot> saveEmergency({
    required String tripId,
    required EmergencyReadinessConfirmations confirmations,
    DateTime? updatedAt,
  }) async {
    final current = await loadOrCreate(tripId);

    final snapshot = current.copyWith(
      emergency: confirmations,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );

    await repository.save(snapshot);
    return snapshot;
  }

  Future<void> remove(String tripId) {
    return repository.remove(tripId);
  }
}
