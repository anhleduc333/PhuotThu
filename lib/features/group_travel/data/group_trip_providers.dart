import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/group_trip_state.dart';
import '../domain/trip_member_view.dart';
import 'group_trip_repository.dart';

final groupTripRepositoryProvider = Provider<GroupTripRepository>((ref) {
  return SupabaseGroupTripRepository(ref.watch(supabaseClientProvider));
});

final groupTripStateProvider = FutureProvider.autoDispose
    .family<GroupTripState, String>((ref, tripId) {
      return ref.watch(groupTripRepositoryProvider).getGroupTripState(tripId);
    });

final tripMemberViewsProvider = FutureProvider.autoDispose
    .family<List<TripMemberView>, String>((ref, tripId) {
      return ref.watch(groupTripRepositoryProvider).getMemberViews(tripId);
    });
