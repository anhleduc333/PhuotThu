import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/trip_invitation.dart';
import '../domain/trip_invitation_inbox_item.dart';
import 'trip_invitation_repository.dart';

final tripInvitationRepositoryProvider = Provider<TripInvitationRepository>((
  ref,
) {
  return SupabaseTripInvitationRepository(ref.watch(supabaseClientProvider));
});

final tripInvitationsProvider = FutureProvider.autoDispose
    .family<List<TripInvitation>, String>((ref, tripId) {
      return ref
          .watch(tripInvitationRepositoryProvider)
          .getInvitationsForTrip(tripId);
    });

final myPendingTripInvitationsProvider =
    FutureProvider.autoDispose<List<TripInvitationInboxItem>>((ref) {
      return ref
          .watch(tripInvitationRepositoryProvider)
          .getMyPendingInvitations();
    });
