import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness_scorer.dart';

void main() {
  const scorer = TripReadinessScorer();

  TripReadinessItem item({
    required TripReadinessItemType type,
    TripReadinessItemStatus status = TripReadinessItemStatus.ready,
    bool required = true,
  }) {
    return TripReadinessItem(
      type: type,
      status: status,
      isRequired: required,
      source: TripReadinessSourceType.manual,
    );
  }

  List<TripReadinessItem> allReadyItems() {
    return [
      item(type: TripReadinessItemType.offlinePackage),
      item(type: TripReadinessItemType.vehicleFuelOrEnergy),
      item(type: TripReadinessItemType.vehicleMechanicalCondition),
      item(type: TripReadinessItemType.vehicleTires),
      item(type: TripReadinessItemType.vehicleDocuments),
      item(type: TripReadinessItemType.personalProtectiveGear),
      item(type: TripReadinessItemType.personalEssentials),
      item(type: TripReadinessItemType.routeReviewed),
      item(type: TripReadinessItemType.weatherReviewed),
      item(type: TripReadinessItemType.connectivityReviewed),
      item(type: TripReadinessItemType.emergencyContacts),
      item(type: TripReadinessItemType.sosPrepared),
      item(type: TripReadinessItemType.firstAidKit),
    ];
  }

  group('TripReadinessScorer', () {
    test('all five categories ready gives 100 percent ready', () {
      final result = scorer.score(items: allReadyItems());

      expect(result, isNotNull);
      expect(result!.assessment.score, 1);
      expect(result.assessment.level, TripReadinessLevel.ready);
      expect(result.assessment.categorySummaries.length, 5);
      expect(result.effectiveCategoryWeights.length, 5);
    });

    test('missing required item forces overall notReady', () {
      final items = allReadyItems();

      items[3] = item(
        type: TripReadinessItemType.vehicleTires,
        status: TripReadinessItemStatus.missing,
      );

      final result = scorer.score(items: items);

      expect(result, isNotNull);
      expect(result!.assessment.level, TripReadinessLevel.notReady);
      expect(result.assessment.hasBlockingItems, isTrue);
    });

    test('unknown required item forces overall notReady', () {
      final items = allReadyItems();

      items[8] = item(
        type: TripReadinessItemType.weatherReviewed,
        status: TripReadinessItemStatus.unknown,
      );

      final result = scorer.score(items: items);

      expect(result, isNotNull);
      expect(result!.assessment.level, TripReadinessLevel.notReady);
    });

    test('needsAttention required item prevents ready', () {
      final items = allReadyItems();

      items[11] = item(
        type: TripReadinessItemType.sosPrepared,
        status: TripReadinessItemStatus.needsAttention,
      );

      final result = scorer.score(items: items);

      expect(result, isNotNull);
      expect(result!.assessment.score, lessThan(1));
      expect(result.assessment.level, TripReadinessLevel.needsAttention);
    });

    test('optional missing item can lower score without hard block', () {
      final items = allReadyItems();

      items.add(
        item(
          type: TripReadinessItemType.firstAidKit,
          status: TripReadinessItemStatus.missing,
          required: false,
        ),
      );

      final result = scorer.score(items: items);

      expect(result, isNotNull);
      expect(result!.assessment.hasBlockingItems, isFalse);
      expect(result.assessment.score, lessThan(1));
    });

    test('notApplicable item is excluded from category penalty', () {
      final result = scorer.score(
        items: [
          item(type: TripReadinessItemType.offlinePackage),
          item(
            type: TripReadinessItemType.personalProtectiveGear,
            status: TripReadinessItemStatus.notApplicable,
            required: false,
          ),
          item(
            type: TripReadinessItemType.personalEssentials,
            status: TripReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);

      final personal = result!.assessment.summaryForCategory(
        TripReadinessCategory.personal,
      );

      expect(personal, isNotNull);
      expect(personal!.score, 1);
    });

    test('category summary reports counts correctly', () {
      final result = scorer.score(
        items: [
          item(
            type: TripReadinessItemType.vehicleFuelOrEnergy,
            status: TripReadinessItemStatus.ready,
          ),
          item(
            type: TripReadinessItemType.vehicleMechanicalCondition,
            status: TripReadinessItemStatus.needsAttention,
          ),
          item(
            type: TripReadinessItemType.vehicleTires,
            status: TripReadinessItemStatus.missing,
          ),
          item(
            type: TripReadinessItemType.vehicleDocuments,
            status: TripReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);

      final vehicle = result!.assessment.summaryForCategory(
        TripReadinessCategory.vehicle,
      );

      expect(vehicle, isNotNull);
      expect(vehicle!.itemCount, 4);
      expect(vehicle.requiredItemCount, 4);
      expect(vehicle.readyRequiredItemCount, 2);
      expect(vehicle.blockingItemCount, 1);
      expect(vehicle.attentionItemCount, 1);
      expect(vehicle.level, TripReadinessLevel.notReady);
    });

    test('category weights affect aggregate score', () {
      final result = scorer.score(
        items: [
          item(type: TripReadinessItemType.offlinePackage),
          item(
            type: TripReadinessItemType.vehicleFuelOrEnergy,
            status: TripReadinessItemStatus.ready,
            required: false,
          ),
          item(
            type: TripReadinessItemType.vehicleTires,
            status: TripReadinessItemStatus.missing,
            required: false,
          ),
        ],
      );

      expect(result, isNotNull);

      // Offline = 1.0 with weight .20
      // Vehicle = 0.5 with weight .25
      // Aggregate = (.20 + .125) / .45
      expect(result!.assessment.score, closeTo(0.722222, 0.0001));
    });

    test('needsAttention factor is configurable', () {
      const policy = TripReadinessScoringPolicy(needsAttentionFactor: 0.8);

      final result = scorer.score(
        policy: policy,
        items: [
          item(
            type: TripReadinessItemType.personalProtectiveGear,
            status: TripReadinessItemStatus.needsAttention,
            required: false,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 0.8);
    });

    test('assessedAt is normalized to UTC', () {
      final assessedAt = DateTime.parse('2026-10-25T14:00:00+07:00');

      final result = scorer.score(
        items: allReadyItems(),
        assessedAt: assessedAt,
      );

      expect(result, isNotNull);
      expect(result!.assessment.assessedAt, isNotNull);
      expect(result.assessment.assessedAt!.isUtc, isTrue);
      expect(result.assessment.assessedAt!.hour, 7);
    });

    test('only populated categories contribute to denominator', () {
      final result = scorer.score(
        items: [item(type: TripReadinessItemType.offlinePackage)],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 1);
      expect(result.effectiveCategoryWeights.keys, {
        TripReadinessCategory.offline,
      });
    });

    test('category score override preserves precise subsystem score', () {
      final result = scorer.score(
        items: [
          item(
            type: TripReadinessItemType.offlinePackage,
            status: TripReadinessItemStatus.needsAttention,
          ),
        ],
        categoryScoreOverrides: const {TripReadinessCategory.offline: 0.92},
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, closeTo(0.92, 0.0001));

      final offline = result.assessment.summaryForCategory(
        TripReadinessCategory.offline,
      );

      expect(offline, isNotNull);
      expect(offline!.score, closeTo(0.92, 0.0001));
      expect(offline.level, TripReadinessLevel.needsAttention);
      expect(result.assessment.level, TripReadinessLevel.needsAttention);
    });

    test('rejects invalid category score override', () {
      expect(
        scorer.score(
          items: [item(type: TripReadinessItemType.offlinePackage)],
          categoryScoreOverrides: const {TripReadinessCategory.offline: 1.2},
        ),
        isNull,
      );
    });

    test('returns null for empty items', () {
      expect(scorer.score(items: const []), isNull);
    });

    test('returns null for invalid policy', () {
      const policy = TripReadinessScoringPolicy(
        readyThreshold: 0.4,
        needsAttentionThreshold: 0.8,
      );

      expect(scorer.score(items: allReadyItems(), policy: policy), isNull);
    });
  });
}
