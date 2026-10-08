import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip.dart';
import 'trip_repository.dart';

final currentTripsProvider = FutureProvider<List<Trip>>((ref) async {
  return ref.watch(tripRepositoryProvider).getTrips();
});

final tripByIdProvider = FutureProvider.family<Trip, String>((
  ref,
  tripId,
) async {
  return ref.watch(tripRepositoryProvider).getTripById(tripId);
});
