import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'geolocator_trip_location_source.dart';
import 'group_trip_providers.dart';
import 'trip_live_location_providers.dart';
import 'trip_live_location_publisher.dart';
import 'trip_live_location_sharing_service.dart';
import 'trip_location_source.dart';

final tripLocationSourceProvider = Provider<TripLocationSource>((ref) {
  return const GeolocatorTripLocationSource();
});

final tripLiveLocationPublisherProvider = Provider<TripLiveLocationPublisher>((
  ref,
) {
  final publisher = TripLiveLocationPublisher(
    locationSource: ref.watch(tripLocationSourceProvider),
    repository: ref.watch(tripLiveLocationRepositoryProvider),
  );

  ref.onDispose(() {
    publisher.dispose();
  });

  return publisher;
});

final tripLiveLocationSharingServiceProvider =
    Provider<TripLiveLocationSharingService>((ref) {
      return TripLiveLocationSharingService(
        groupRepository: ref.watch(groupTripRepositoryProvider),
        publisher: ref.watch(tripLiveLocationPublisherProvider),
      );
    });
