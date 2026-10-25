import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/data/trip_readiness_checklist_providers.dart';
import 'package:phuotthu/features/trips/data/trip_readiness_checklist_repository.dart';
import 'package:phuotthu/features/trips/data/trip_readiness_checklist_service.dart';

void main() {
  test('production repository is lazy async shared preferences backend', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(tripReadinessChecklistRepositoryProvider);

    expect(
      repository,
      isA<AsyncSharedPreferencesTripReadinessChecklistRepository>(),
    );
  });

  test('wires checklist service without platform bootstrap', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(tripReadinessChecklistServiceProvider);

    expect(service, isA<TripReadinessChecklistService>());
    expect(
      service.repository,
      isA<AsyncSharedPreferencesTripReadinessChecklistRepository>(),
    );
  });
}
