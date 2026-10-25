import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness.dart';
import 'package:phuotthu/features/trips/domain/offline_trip_readiness_adapter.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';

void main() {
  const adapter = OfflineTripReadinessAdapter();

  OfflineReadinessAssessment assessment({
    required OfflineReadinessLevel level,
    required double score,
    double? warningPercent,
    DateTime? assessedAt,
  }) {
    return OfflineReadinessAssessment(
      level: level,
      score: score,
      items: const [],
      connectivityWarningRoutePercent: warningPercent,
      assessedAt: assessedAt,
    );
  }

  test('ready offline assessment maps to ready trip item', () {
    final item = adapter.adapt(
      assessment(level: OfflineReadinessLevel.ready, score: 1),
    );

    expect(item.type, TripReadinessItemType.offlinePackage);
    expect(item.status, TripReadinessItemStatus.ready);
    expect(item.isRequired, isTrue);
    expect(item.source, TripReadinessSourceType.offlineReadiness);
  });

  test('needsAttention maps without becoming hard missing', () {
    final item = adapter.adapt(
      assessment(level: OfflineReadinessLevel.needsAttention, score: 0.92),
    );

    expect(item.status, TripReadinessItemStatus.needsAttention);
    expect(item.blocksReadiness, isFalse);
    expect(item.preventsReady, isTrue);
  });

  test('notReady maps to missing hard block', () {
    final item = adapter.adapt(
      assessment(level: OfflineReadinessLevel.notReady, score: 0.4),
    );

    expect(item.status, TripReadinessItemStatus.missing);
    expect(item.blocksReadiness, isTrue);
  });

  test('unknown maps to unknown', () {
    final item = adapter.adapt(
      assessment(level: OfflineReadinessLevel.unknown, score: 0),
    );

    expect(item.status, TripReadinessItemStatus.unknown);
  });

  test('description includes score and connectivity context', () {
    final item = adapter.adapt(
      assessment(
        level: OfflineReadinessLevel.needsAttention,
        score: 0.92,
        warningPercent: 10.1,
      ),
    );

    expect(item.description, contains('92%'));
    expect(item.description, contains('10.1%'));
    expect(item.description, contains('HIGH/CRITICAL'));
  });

  test('assessed time is normalized to UTC', () {
    final checkedAt = DateTime.parse('2026-10-25T14:30:00+07:00');

    final item = adapter.adapt(
      assessment(
        level: OfflineReadinessLevel.ready,
        score: 1,
        assessedAt: checkedAt,
      ),
    );

    expect(item.lastCheckedAt, isNotNull);
    expect(item.lastCheckedAt!.isUtc, isTrue);
    expect(item.lastCheckedAt!.hour, 7);
    expect(item.lastCheckedAt!.minute, 30);
  });
}
