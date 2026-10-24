import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/data/offline_trip_cache_providers.dart';
import 'package:phuotthu/features/trips/data/offline_trip_cache_repository.dart';
import 'package:phuotthu/features/trips/data/offline_trip_package_service.dart';

void main() {
  test('production repository can be constructed without plugin platform', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(offlineTripCacheRepositoryProvider);

    expect(repository, isA<AsyncSharedPreferencesOfflineTripCacheRepository>());
  });

  test('wires offline package service without app bootstrap override', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(offlineTripPackageServiceProvider);

    expect(service, isA<OfflineTripPackageService>());
    expect(
      service.repository,
      isA<AsyncSharedPreferencesOfflineTripCacheRepository>(),
    );
  });
}
