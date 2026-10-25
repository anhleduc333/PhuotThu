import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/data/trip_readiness_checklist_repository.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness_checklist_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesTripReadinessChecklistRepository repository;

  TripReadinessChecklistSnapshot snapshot(String tripId) {
    return TripReadinessChecklistSnapshot.empty(
      tripId: tripId,
      updatedAt: DateTime.utc(2026, 10, 25),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesTripReadinessChecklistRepository(preferences);
  });

  test('saves and loads checklist', () async {
    await repository.save(snapshot('trip-1'));

    final loaded = await repository.load('trip-1');

    expect(loaded, isNotNull);
    expect(loaded!.tripId, 'trip-1');
    expect(await repository.exists('trip-1'), isTrue);
  });

  test('save overwrites same trip checklist', () async {
    await repository.save(snapshot('trip-1'));

    final updated = snapshot('trip-1').copyWith(
      routeFingerprint: 'route-v2',
      updatedAt: DateTime.utc(2026, 10, 26),
    );

    await repository.save(updated);

    final loaded = await repository.load('trip-1');

    expect(loaded!.routeFingerprint, 'route-v2');
    expect(loaded.updatedAt, DateTime.utc(2026, 10, 26));
  });

  test('returns null for missing checklist', () async {
    expect(await repository.load('missing'), isNull);
  });

  test('removes checklist', () async {
    await repository.save(snapshot('trip-1'));
    await repository.remove('trip-1');

    expect(await repository.exists('trip-1'), isFalse);
    expect(await repository.load('trip-1'), isNull);
  });

  test('rejects blank trip id', () async {
    expect(() => repository.exists('   '), throwsArgumentError);
  });

  test('throws when cached JSON is corrupted', () async {
    await preferences.setString(
      'trip_readiness_checklist_v1:trip-1',
      '{bad json',
    );

    expect(() => repository.load('trip-1'), throwsA(anything));
  });
}
