import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vehicle.dart';
import 'vehicle_repository.dart';

final currentVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);

  return repository.getVehicles();
});
