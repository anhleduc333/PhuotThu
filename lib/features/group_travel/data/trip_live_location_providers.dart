import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/trip_live_location.dart';
import 'trip_live_location_repository.dart';

final tripLiveLocationRepositoryProvider = Provider<TripLiveLocationRepository>(
  (ref) {
    return SupabaseTripLiveLocationRepository(
      ref.watch(supabaseClientProvider),
    );
  },
);

final tripLiveLocationsProvider = StreamProvider.autoDispose
    .family<List<TripLiveLocation>, String>((ref, tripId) {
      return ref
          .watch(tripLiveLocationRepositoryProvider)
          .watchTripLocations(tripId);
    });
