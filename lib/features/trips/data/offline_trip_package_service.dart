import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';
import '../domain/connectivity_risk.dart';
import '../domain/offline_trip_package_snapshot.dart';
import 'offline_trip_cache_repository.dart';
import 'offline_trip_package_builder.dart';

class OfflineTripPackageService {
  const OfflineTripPackageService({
    required this.repository,
    this.builder = const OfflineTripPackageBuilder(),
  });

  final OfflineTripCacheRepository repository;
  final OfflineTripPackageBuilder builder;

  Future<OfflineTripPackageSnapshot> savePackage({
    required String tripId,
    required String startName,
    required String destinationName,
    required double startLatitude,
    required double startLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required int routeDistanceMeters,
    required int routeDurationSeconds,
    required List<RoutePoint> routePoints,
    String? vehicleId,
    DateTime? plannedStartAt,
    double? budgetTotal,
    List<AlongRoutePlace> pois = const [],
    ConnectivityRiskAssessment? connectivityAssessment,
    bool connectivityProxyOnly = true,
    DateTime? savedAt,
  }) async {
    final snapshot = builder.build(
      tripId: tripId,
      startName: startName,
      destinationName: destinationName,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      routeDistanceMeters: routeDistanceMeters,
      routeDurationSeconds: routeDurationSeconds,
      routePoints: routePoints,
      vehicleId: vehicleId,
      plannedStartAt: plannedStartAt,
      budgetTotal: budgetTotal,
      pois: pois,
      connectivityAssessment: connectivityAssessment,
      connectivityProxyOnly: connectivityProxyOnly,
      savedAt: savedAt,
    );

    await repository.save(snapshot);

    return snapshot;
  }

  Future<OfflineTripPackageSnapshot?> loadPackage(String tripId) {
    return repository.load(tripId);
  }

  Future<bool> hasPackage(String tripId) {
    return repository.exists(tripId);
  }

  Future<void> removePackage(String tripId) {
    return repository.remove(tripId);
  }
}
