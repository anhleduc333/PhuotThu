import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_member_view.dart';
import 'group_trip_providers.dart';

final tripLiveMapMembersProvider =
    FutureProvider.family<List<TripMemberView>, String>((ref, tripId) {
      return ref.watch(groupTripRepositoryProvider).getMemberViews(tripId);
    });
