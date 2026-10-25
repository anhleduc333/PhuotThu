import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';

void main() {
  group('TripReadinessLevel', () {
    test('exposes labels and action flags', () {
      expect(TripReadinessLevel.ready.label, 'Sẵn sàng');
      expect(TripReadinessLevel.ready.isReady, isTrue);
      expect(TripReadinessLevel.notReady.requiresAction, isTrue);
      expect(TripReadinessLevel.needsAttention.requiresAction, isTrue);
      expect(TripReadinessLevel.unknown.severity, -1);
      expect(TripReadinessLevel.notReady.severity, 2);
    });
  });

  group('TripReadinessItemType', () {
    test('maps item types to expected categories', () {
      expect(
        TripReadinessItemType.offlinePackage.category,
        TripReadinessCategory.offline,
      );
      expect(
        TripReadinessItemType.vehicleTires.category,
        TripReadinessCategory.vehicle,
      );
      expect(
        TripReadinessItemType.personalProtectiveGear.category,
        TripReadinessCategory.personal,
      );
      expect(
        TripReadinessItemType.weatherReviewed.category,
        TripReadinessCategory.route,
      );
      expect(
        TripReadinessItemType.sosPrepared.category,
        TripReadinessCategory.emergency,
      );
    });

    test('uses stable keys', () {
      expect(
        TripReadinessItemType.vehicleMechanicalCondition.key,
        'vehicle_mechanical_condition',
      );
      expect(TripReadinessItemType.emergencyContacts.key, 'emergency_contacts');
    });
  });

  group('TripReadinessItem', () {
    test('uses default label as display title', () {
      const item = TripReadinessItem(
        type: TripReadinessItemType.vehicleTires,
        status: TripReadinessItemStatus.ready,
        isRequired: true,
        source: TripReadinessSourceType.manual,
      );

      expect(item.displayTitle, 'Lốp xe');
      expect(item.category, TripReadinessCategory.vehicle);
    });

    test('uses trimmed custom title', () {
      const item = TripReadinessItem(
        type: TripReadinessItemType.personalEssentials,
        status: TripReadinessItemStatus.ready,
        isRequired: false,
        source: TripReadinessSourceType.manual,
        title: '  Đồ cá nhân  ',
      );

      expect(item.displayTitle, 'Đồ cá nhân');
    });

    test('missing required item blocks readiness', () {
      const item = TripReadinessItem(
        type: TripReadinessItemType.vehicleMechanicalCondition,
        status: TripReadinessItemStatus.missing,
        isRequired: true,
        source: TripReadinessSourceType.manual,
      );

      expect(item.blocksReadiness, isTrue);
      expect(item.preventsReady, isTrue);
      expect(item.requiresAction, isTrue);
    });

    test(
      'needsAttention required item prevents ready but is not hard block',
      () {
        const item = TripReadinessItem(
          type: TripReadinessItemType.vehicleTires,
          status: TripReadinessItemStatus.needsAttention,
          isRequired: true,
          source: TripReadinessSourceType.manual,
        );

        expect(item.blocksReadiness, isFalse);
        expect(item.preventsReady, isTrue);
        expect(item.requiresAction, isTrue);
      },
    );

    test('optional missing item does not block readiness', () {
      const item = TripReadinessItem(
        type: TripReadinessItemType.firstAidKit,
        status: TripReadinessItemStatus.missing,
        isRequired: false,
        source: TripReadinessSourceType.manual,
      );

      expect(item.blocksReadiness, isFalse);
      expect(item.requiresAction, isTrue);
    });

    test('copyWith updates selected fields', () {
      const item = TripReadinessItem(
        type: TripReadinessItemType.routeReviewed,
        status: TripReadinessItemStatus.unknown,
        isRequired: true,
        source: TripReadinessSourceType.routeAnalysis,
      );

      final updated = item.copyWith(status: TripReadinessItemStatus.ready);

      expect(updated.status, TripReadinessItemStatus.ready);
      expect(updated.type, item.type);
      expect(updated.source, item.source);
      expect(updated.isRequired, isTrue);
    });
  });

  group('TripReadinessAssessment', () {
    const items = [
      TripReadinessItem(
        type: TripReadinessItemType.offlinePackage,
        status: TripReadinessItemStatus.ready,
        isRequired: true,
        source: TripReadinessSourceType.offlineReadiness,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleMechanicalCondition,
        status: TripReadinessItemStatus.ready,
        isRequired: true,
        source: TripReadinessSourceType.manual,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleTires,
        status: TripReadinessItemStatus.missing,
        isRequired: true,
        source: TripReadinessSourceType.manual,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.firstAidKit,
        status: TripReadinessItemStatus.missing,
        isRequired: false,
        source: TripReadinessSourceType.manual,
      ),
    ];

    const summaries = [
      TripReadinessCategorySummary(
        category: TripReadinessCategory.offline,
        level: TripReadinessLevel.ready,
        score: 1,
        itemCount: 1,
        requiredItemCount: 1,
        readyRequiredItemCount: 1,
        blockingItemCount: 0,
        attentionItemCount: 0,
      ),
      TripReadinessCategorySummary(
        category: TripReadinessCategory.vehicle,
        level: TripReadinessLevel.notReady,
        score: 0.5,
        itemCount: 2,
        requiredItemCount: 2,
        readyRequiredItemCount: 1,
        blockingItemCount: 1,
        attentionItemCount: 1,
      ),
    ];

    test('calculates required completion', () {
      const assessment = TripReadinessAssessment(
        level: TripReadinessLevel.notReady,
        score: 0.6,
        items: items,
        categorySummaries: summaries,
      );

      expect(assessment.requiredItemCount, 3);
      expect(assessment.readyRequiredItemCount, 2);
      expect(assessment.requiredCompletionRatio, closeTo(2 / 3, 0.0001));
      expect(assessment.requiredCompletionPercent, closeTo(66.6667, 0.001));
    });

    test('returns blocking and action items', () {
      const assessment = TripReadinessAssessment(
        level: TripReadinessLevel.notReady,
        score: 0.6,
        items: items,
        categorySummaries: summaries,
      );

      expect(assessment.blockingItems.length, 1);
      expect(
        assessment.blockingItems.single.type,
        TripReadinessItemType.vehicleTires,
      );
      expect(assessment.actionItems.length, 2);
      expect(assessment.hasBlockingItems, isTrue);
    });

    test('filters items by category', () {
      const assessment = TripReadinessAssessment(
        level: TripReadinessLevel.notReady,
        score: 0.6,
        items: items,
        categorySummaries: summaries,
      );

      final vehicleItems = assessment.itemsForCategory(
        TripReadinessCategory.vehicle,
      );

      expect(vehicleItems.length, 2);
      expect(
        vehicleItems.every(
          (item) => item.category == TripReadinessCategory.vehicle,
        ),
        isTrue,
      );
    });

    test('finds category summary', () {
      const assessment = TripReadinessAssessment(
        level: TripReadinessLevel.notReady,
        score: 0.6,
        items: items,
        categorySummaries: summaries,
      );

      expect(
        assessment.summaryForCategory(TripReadinessCategory.vehicle)!.level,
        TripReadinessLevel.notReady,
      );

      expect(
        assessment.summaryForCategory(TripReadinessCategory.emergency),
        isNull,
      );
    });

    test('no required items means full required completion', () {
      const assessment = TripReadinessAssessment(
        level: TripReadinessLevel.ready,
        score: 1,
        items: [
          TripReadinessItem(
            type: TripReadinessItemType.firstAidKit,
            status: TripReadinessItemStatus.ready,
            isRequired: false,
            source: TripReadinessSourceType.manual,
          ),
        ],
        categorySummaries: [],
      );

      expect(assessment.requiredItemCount, 0);
      expect(assessment.requiredCompletionRatio, 1);
      expect(assessment.requiredCompletionPercent, 100);
    });
  });
}
