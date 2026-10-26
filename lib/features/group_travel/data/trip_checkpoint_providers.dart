import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/trip_checkpoint.dart';
import '../domain/trip_checkpoint_arrival.dart';
import '../domain/trip_checkpoint_progress.dart';
import 'group_trip_providers.dart';
import 'trip_checkpoint_repository.dart';

final tripCheckpointRepositoryProvider = Provider<TripCheckpointRepository>((
  ref,
) {
  return SupabaseTripCheckpointRepository(ref.watch(supabaseClientProvider));
});

final tripCheckpointsProvider = FutureProvider.autoDispose
    .family<List<TripCheckpoint>, String>((ref, tripId) {
      return ref.watch(tripCheckpointRepositoryProvider).getCheckpoints(tripId);
    });

final tripCheckpointArrivalsProvider = FutureProvider.autoDispose
    .family<List<TripCheckpointArrival>, String>((ref, tripId) {
      return ref.watch(tripCheckpointRepositoryProvider).getArrivals(tripId);
    });

final tripCheckpointProgressProvider = FutureProvider.autoDispose
    .family<List<TripCheckpointProgress>, String>((ref, tripId) async {
      final checkpoints = await ref.watch(
        tripCheckpointsProvider(tripId).future,
      );
      final arrivals = await ref.watch(
        tripCheckpointArrivalsProvider(tripId).future,
      );
      final group = await ref.watch(groupTripStateProvider(tripId).future);
      final activeIds = <String>{
        group.ownerId,
        ...group.activeMembers.map((member) => member.userId),
      };
      return List<TripCheckpointProgress>.unmodifiable(
        checkpoints.map(
          (checkpoint) => TripCheckpointProgress(
            checkpoint: checkpoint,
            activeUserIds: activeIds,
            arrivals: arrivals,
          ),
        ),
      );
    });
