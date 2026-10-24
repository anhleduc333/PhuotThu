import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_trip_cache_repository.dart';
import 'offline_trip_package_builder.dart';
import 'offline_trip_package_service.dart';

final offlineTripCacheRepositoryProvider = Provider<OfflineTripCacheRepository>(
  (ref) {
    return AsyncSharedPreferencesOfflineTripCacheRepository();
  },
);

final offlineTripPackageBuilderProvider = Provider<OfflineTripPackageBuilder>((
  ref,
) {
  return const OfflineTripPackageBuilder();
});

final offlineTripPackageServiceProvider = Provider<OfflineTripPackageService>((
  ref,
) {
  return OfflineTripPackageService(
    repository: ref.watch(offlineTripCacheRepositoryProvider),
    builder: ref.watch(offlineTripPackageBuilderProvider),
  );
});
