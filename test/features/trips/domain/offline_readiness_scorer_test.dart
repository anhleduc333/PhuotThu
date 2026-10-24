import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness_scorer.dart';

void main() {
  const scorer = OfflineReadinessScorer();

  OfflineReadinessItem item({
    required OfflineReadinessItemType type,
    required OfflineReadinessItemStatus status,
    bool required = false,
  }) {
    return OfflineReadinessItem(
      type: type,
      status: status,
      isRequired: required,
    );
  }

  group('OfflineReadinessScorer', () {
    test('returns ready when all applicable items are ready', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.ready,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.ready,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.routeSummary,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.essentialPois,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.emergencyInfo,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.connectivityRiskAnalysis,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 1);
      expect(result.assessment.level, OfflineReadinessLevel.ready);
    });

    test('missing required item forces notReady', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.ready,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.missing,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.level, OfflineReadinessLevel.notReady);
      expect(
        result.assessment.missingRequiredItems.single.type,
        OfflineReadinessItemType.routeGeometry,
      );
    });

    test('stale required item prevents ready state', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.stale,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.ready,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.routeSummary,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.essentialPois,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.emergencyInfo,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.connectivityRiskAnalysis,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.level, OfflineReadinessLevel.needsAttention);
      expect(result.assessment.staleRequiredItems.length, 1);
    });

    test('stale items receive partial score', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.stale,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 0.5);
      expect(result.breakdown.single.statusFactor, 0.5);
    });

    test('optional notApplicable items are excluded from denominator', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.notApplicable,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 1);
      expect(result.breakdown.length, 1);
    });

    test('required notApplicable item lowers score and prevents ready', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.ready,
            required: true,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.notApplicable,
            required: true,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, lessThan(1));
      expect(result.assessment.level, OfflineReadinessLevel.needsAttention);

      final mapBreakdown = result.breakdown.singleWhere(
        (entry) => entry.item.type == OfflineReadinessItemType.offlineMap,
      );

      expect(mapBreakdown.statusFactor, 0.5);
    });

    test(
      'moderate connectivity risk escalates offline map and risk analysis',
      () {
        final result = scorer.score(
          connectivityWarningRoutePercent: 15,
          items: [
            item(
              type: OfflineReadinessItemType.tripDetails,
              status: OfflineReadinessItemStatus.ready,
              required: true,
            ),
            item(
              type: OfflineReadinessItemType.routeGeometry,
              status: OfflineReadinessItemStatus.ready,
              required: true,
            ),
            item(
              type: OfflineReadinessItemType.connectivityRiskAnalysis,
              status: OfflineReadinessItemStatus.ready,
            ),
            item(
              type: OfflineReadinessItemType.offlineMap,
              status: OfflineReadinessItemStatus.missing,
            ),
          ],
        );

        expect(result, isNotNull);
        expect(result!.hasConnectivityEscalation, isTrue);

        expect(
          result.connectivityEscalatedTypes,
          containsAll({
            OfflineReadinessItemType.offlineMap,
            OfflineReadinessItemType.connectivityRiskAnalysis,
          }),
        );

        final offlineMap = result.assessment.items.singleWhere(
          (item) => item.type == OfflineReadinessItemType.offlineMap,
        );

        expect(offlineMap.isRequired, isTrue);
        expect(result.assessment.level, OfflineReadinessLevel.notReady);
      },
    );

    test('high connectivity risk also escalates POIs and emergency info', () {
      final result = scorer.score(
        connectivityWarningRoutePercent: 35,
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.essentialPois,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.emergencyInfo,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.connectivityRiskAnalysis,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(
        result!.connectivityEscalatedTypes,
        containsAll({
          OfflineReadinessItemType.offlineMap,
          OfflineReadinessItemType.connectivityRiskAnalysis,
          OfflineReadinessItemType.essentialPois,
          OfflineReadinessItemType.emergencyInfo,
        }),
      );

      expect(
        result.assessment.items
            .where(
              (item) => result.connectivityEscalatedTypes.contains(item.type),
            )
            .every((item) => item.isRequired),
        isTrue,
      );
    });

    test('low connectivity risk does not escalate optional items', () {
      final result = scorer.score(
        connectivityWarningRoutePercent: 5,
        items: [
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.missing,
          ),
          item(
            type: OfflineReadinessItemType.connectivityRiskAnalysis,
            status: OfflineReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.connectivityEscalatedTypes, isEmpty);
      expect(result.assessment.items.first.isRequired, isFalse);
    });

    test('uses type weights in score calculation', () {
      final result = scorer.score(
        items: [
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.routeSummary,
            status: OfflineReadinessItemStatus.missing,
          ),
        ],
      );

      expect(result, isNotNull);

      // 0.25 / (0.25 + 0.10)
      expect(result!.assessment.score, closeTo(0.714285, 0.0001));
    });

    test('supports custom stale factor and thresholds', () {
      const policy = OfflineReadinessScoringPolicy(
        staleFactor: 0.8,
        readyThreshold: 0.75,
        needsAttentionThreshold: 0.4,
      );

      final result = scorer.score(
        policy: policy,
        items: [
          item(
            type: OfflineReadinessItemType.routeGeometry,
            status: OfflineReadinessItemStatus.stale,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 0.8);
      expect(result.assessment.level, OfflineReadinessLevel.ready);
    });

    test('supports custom factor for required unsupported capability', () {
      const policy = OfflineReadinessScoringPolicy(
        requiredUnsupportedFactor: 0.25,
      );

      final result = scorer.score(
        policy: policy,
        items: [
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.notApplicable,
            required: true,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.score, 0.25);
      expect(result.assessment.level, OfflineReadinessLevel.notReady);
    });

    test('preserves assessed time and connectivity context', () {
      final assessedAt = DateTime.utc(2026, 10, 25);

      final result = scorer.score(
        assessedAt: assessedAt,
        connectivityWarningRoutePercent: 22.5,
        items: [
          item(
            type: OfflineReadinessItemType.tripDetails,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.offlineMap,
            status: OfflineReadinessItemStatus.ready,
          ),
          item(
            type: OfflineReadinessItemType.connectivityRiskAnalysis,
            status: OfflineReadinessItemStatus.ready,
          ),
        ],
      );

      expect(result, isNotNull);
      expect(result!.assessment.assessedAt, assessedAt);
      expect(result.assessment.connectivityWarningRoutePercent, 22.5);
    });

    test('returns null for invalid inputs', () {
      expect(scorer.score(items: const []), isNull);

      expect(
        scorer.score(
          connectivityWarningRoutePercent: 101,
          items: [
            item(
              type: OfflineReadinessItemType.tripDetails,
              status: OfflineReadinessItemStatus.ready,
            ),
          ],
        ),
        isNull,
      );

      expect(
        scorer.score(
          policy: const OfflineReadinessScoringPolicy(
            readyThreshold: 0.4,
            needsAttentionThreshold: 0.7,
          ),
          items: [
            item(
              type: OfflineReadinessItemType.tripDetails,
              status: OfflineReadinessItemStatus.ready,
            ),
          ],
        ),
        isNull,
      );

      expect(
        scorer.score(
          policy: const OfflineReadinessScoringPolicy(
            requiredUnsupportedFactor: 1,
          ),
          items: [
            item(
              type: OfflineReadinessItemType.tripDetails,
              status: OfflineReadinessItemStatus.ready,
            ),
          ],
        ),
        isNull,
      );
    });
  });
}
