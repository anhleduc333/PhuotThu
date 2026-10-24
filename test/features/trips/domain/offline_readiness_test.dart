import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness.dart';

void main() {
  group('OfflineReadinessLevel', () {
    test('exposes expected labels and readiness flags', () {
      expect(OfflineReadinessLevel.unknown.label, 'Chưa đánh giá');
      expect(OfflineReadinessLevel.notReady.requiresAction, isTrue);
      expect(OfflineReadinessLevel.needsAttention.requiresAction, isTrue);
      expect(OfflineReadinessLevel.ready.isReady, isTrue);
      expect(OfflineReadinessLevel.ready.requiresAction, isFalse);
    });
  });

  group('OfflineReadinessItem', () {
    test('uses default type label when custom title is absent', () {
      const item = OfflineReadinessItem(
        type: OfflineReadinessItemType.routeGeometry,
        status: OfflineReadinessItemStatus.ready,
        isRequired: true,
      );

      expect(item.displayTitle, 'Dữ liệu tuyến đường');
    });

    test('uses trimmed custom title', () {
      const item = OfflineReadinessItem(
        type: OfflineReadinessItemType.offlineMap,
        status: OfflineReadinessItemStatus.ready,
        isRequired: false,
        title: '  Bản đồ chuyến đi  ',
      );

      expect(item.displayTitle, 'Bản đồ chuyến đi');
    });

    test('detects blocking required item', () {
      const missing = OfflineReadinessItem(
        type: OfflineReadinessItemType.routeGeometry,
        status: OfflineReadinessItemStatus.missing,
        isRequired: true,
      );

      const stale = OfflineReadinessItem(
        type: OfflineReadinessItemType.tripDetails,
        status: OfflineReadinessItemStatus.stale,
        isRequired: true,
      );

      const optionalMissing = OfflineReadinessItem(
        type: OfflineReadinessItemType.offlineMap,
        status: OfflineReadinessItemStatus.missing,
        isRequired: false,
      );

      expect(missing.blocksReadiness, isTrue);
      expect(stale.blocksReadiness, isTrue);
      expect(optionalMissing.blocksReadiness, isFalse);
    });

    test('not applicable item does not block readiness', () {
      const item = OfflineReadinessItem(
        type: OfflineReadinessItemType.offlineMap,
        status: OfflineReadinessItemStatus.notApplicable,
        isRequired: true,
      );

      expect(item.blocksReadiness, isFalse);
      expect(item.status.isUsable, isTrue);
    });

    test('converts estimated bytes to MB', () {
      const item = OfflineReadinessItem(
        type: OfflineReadinessItemType.offlineMap,
        status: OfflineReadinessItemStatus.ready,
        isRequired: false,
        estimatedSizeBytes: 5 * 1024 * 1024,
      );

      expect(item.estimatedSizeMb, 5);
    });
  });

  group('OfflineReadinessAssessment', () {
    const items = [
      OfflineReadinessItem(
        type: OfflineReadinessItemType.tripDetails,
        status: OfflineReadinessItemStatus.ready,
        isRequired: true,
        estimatedSizeBytes: 1024 * 1024,
      ),
      OfflineReadinessItem(
        type: OfflineReadinessItemType.routeGeometry,
        status: OfflineReadinessItemStatus.ready,
        isRequired: true,
        estimatedSizeBytes: 2 * 1024 * 1024,
      ),
      OfflineReadinessItem(
        type: OfflineReadinessItemType.essentialPois,
        status: OfflineReadinessItemStatus.missing,
        isRequired: true,
      ),
      OfflineReadinessItem(
        type: OfflineReadinessItemType.connectivityRiskAnalysis,
        status: OfflineReadinessItemStatus.stale,
        isRequired: false,
      ),
    ];

    test('calculates required completion ratio', () {
      const assessment = OfflineReadinessAssessment(
        level: OfflineReadinessLevel.needsAttention,
        score: 0.7,
        items: items,
      );

      expect(assessment.requiredItemCount, 3);
      expect(assessment.readyRequiredItemCount, 2);
      expect(assessment.requiredCompletionRatio, closeTo(2 / 3, 0.0001));
      expect(assessment.requiredCompletionPercent, closeTo(66.6667, 0.001));
    });

    test('lists missing and stale required items', () {
      const assessment = OfflineReadinessAssessment(
        level: OfflineReadinessLevel.notReady,
        score: 0.4,
        items: [
          OfflineReadinessItem(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.missing,
            isRequired: true,
          ),
          OfflineReadinessItem(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.stale,
            isRequired: true,
          ),
          OfflineReadinessItem(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.missing,
            isRequired: false,
          ),
        ],
      );

      expect(assessment.missingRequiredItems.length, 1);
      expect(assessment.staleRequiredItems.length, 1);
      expect(assessment.actionItems.length, 3);
      expect(assessment.hasBlockingItems, isTrue);
    });

    test('exposes connectivity risk context', () {
      const assessment = OfflineReadinessAssessment(
        level: OfflineReadinessLevel.needsAttention,
        score: 0.75,
        items: [],
        connectivityWarningRoutePercent: 28.5,
      );

      expect(assessment.hasConnectivityRiskContext, isTrue);
      expect(assessment.connectivityWarningRoutePercent, 28.5);
    });

    test('handles assessment without connectivity risk context', () {
      const assessment = OfflineReadinessAssessment(
        level: OfflineReadinessLevel.unknown,
        score: 0,
        items: [],
      );

      expect(assessment.hasConnectivityRiskContext, isFalse);
      expect(assessment.connectivityWarningRoutePercent, isNull);
    });

    test('sums estimated offline size', () {
      const assessment = OfflineReadinessAssessment(
        level: OfflineReadinessLevel.ready,
        score: 1,
        items: items,
      );

      expect(assessment.totalEstimatedSizeBytes, 3 * 1024 * 1024);
      expect(assessment.totalEstimatedSizeMb, 3);
    });

    test('returns full completion when there are no required items', () {
      const assessment = OfflineReadinessAssessment(
        level: OfflineReadinessLevel.ready,
        score: 1,
        items: [
          OfflineReadinessItem(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.ready,
            isRequired: false,
          ),
        ],
      );

      expect(assessment.requiredItemCount, 0);
      expect(assessment.requiredCompletionRatio, 1);
      expect(assessment.requiredCompletionPercent, 100);
      expect(assessment.hasBlockingItems, isFalse);
    });
  });
}
