import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness_evaluator.dart';
import 'package:phuotthu/features/trips/domain/offline_trip_package_snapshot.dart';

void main() {
  const evaluator = OfflineReadinessEvaluator();

  OfflineTripPackageSnapshot snapshot({
    List<OfflinePoiSnapshot> pois = const [],
    OfflineConnectivitySnapshot? connectivity,
  }) {
    return OfflineTripPackageSnapshot(
      schemaVersion: OfflineTripPackageSnapshot.currentSchemaVersion,
      savedAt: DateTime.utc(2026, 10, 25, 2),
      trip: const OfflineTripSnapshot(
        tripId: 'trip-1',
        startName: 'Hà Nội',
        destinationName: 'Hà Giang',
        startLatitude: 21,
        startLongitude: 105,
        destinationLatitude: 22,
        destinationLongitude: 106,
      ),
      route: const OfflineRouteSnapshot(
        distanceMeters: 300000,
        durationSeconds: 21600,
        points: [
          OfflineRoutePointSnapshot(latitude: 21, longitude: 105),
          OfflineRoutePointSnapshot(latitude: 22, longitude: 106),
        ],
      ),
      pois: pois,
      connectivity: connectivity,
    );
  }

  const poi = OfflinePoiSnapshot(
    id: 'poi-1',
    name: 'Cây xăng A',
    typeKey: 'fuel',
    latitude: 21.5,
    longitude: 105.5,
    source: 'geoapify',
    sourceId: 'source-1',
  );

  OfflineConnectivitySnapshot connectivity({double warningPercent = 5}) {
    return OfflineConnectivitySnapshot(
      overallRiskScore: 0.4,
      overallLevelKey: 'moderate',
      warningRoutePercent: warningPercent,
      proxyOnly: true,
      generatedAt: DateTime.utc(2026, 10, 25, 1),
      segments: const [],
    );
  }

  test('no package is not ready', () {
    final result = evaluator.evaluate(snapshot: null);

    expect(result.assessment.level, OfflineReadinessLevel.notReady);
    expect(result.assessment.score, 0);
    expect(result.assessment.missingRequiredItems.length, 3);
  });

  test('complete supported package is ready', () {
    final result = evaluator.evaluate(
      snapshot: snapshot(pois: const [poi], connectivity: connectivity()),
    );

    expect(result.assessment.level, OfflineReadinessLevel.ready);
    expect(result.assessment.score, 1);
    expect(result.assessment.hasBlockingItems, isFalse);
  });

  test('package without optional POIs and connectivity needs attention', () {
    final result = evaluator.evaluate(snapshot: snapshot());

    expect(result.assessment.level, OfflineReadinessLevel.needsAttention);
    expect(result.assessment.score, greaterThan(0.55));
    expect(result.assessment.score, lessThan(0.85));
  });

  test('stale package is no longer ready', () {
    final result = evaluator.evaluate(
      snapshot: snapshot(pois: const [poi], connectivity: connectivity()),
      packageNeedsRefresh: true,
    );

    expect(result.assessment.isReady, isFalse);
    expect(result.assessment.requiresAction, isTrue);
    expect(
      result.assessment.items
          .where(
            (item) => item.status != OfflineReadinessItemStatus.notApplicable,
          )
          .every((item) => item.status == OfflineReadinessItemStatus.stale),
      isTrue,
    );
  });

  test('high connectivity risk makes missing POIs blocking', () {
    final result = evaluator.evaluate(
      snapshot: snapshot(connectivity: connectivity(warningPercent: 35)),
    );

    expect(result.hasConnectivityEscalation, isTrue);
    expect(
      result.connectivityEscalatedTypes,
      contains(OfflineReadinessItemType.essentialPois),
    );
    expect(result.assessment.level, OfflineReadinessLevel.notReady);
    expect(
      result.assessment.missingRequiredItems.any(
        (item) => item.type == OfflineReadinessItemType.essentialPois,
      ),
      isTrue,
    );
  });

  test('10 percent warning cannot be 100 percent ready while offline map is unsupported', () {
    final result = evaluator.evaluate(
      snapshot: snapshot(
        pois: const [poi],
        connectivity: connectivity(warningPercent: 10.1),
      ),
    );

    expect(result.hasConnectivityEscalation, isTrue);
    expect(
      result.connectivityEscalatedTypes,
      containsAll({
        OfflineReadinessItemType.connectivityRiskAnalysis,
        OfflineReadinessItemType.offlineMap,
      }),
    );

    final offlineMap = result.assessment.items.singleWhere(
      (item) => item.type == OfflineReadinessItemType.offlineMap,
    );

    expect(offlineMap.isRequired, isTrue);
    expect(offlineMap.status, OfflineReadinessItemStatus.notApplicable);

    expect(result.assessment.score, lessThan(1));
    expect(result.assessment.level, OfflineReadinessLevel.needsAttention);
    expect(result.assessment.isReady, isFalse);
  });

  test('moderate warning escalates connectivity and offline map types', () {
    final result = evaluator.evaluate(
      snapshot: snapshot(
        pois: const [poi],
        connectivity: connectivity(warningPercent: 15),
      ),
    );

    expect(
      result.connectivityEscalatedTypes,
      containsAll({
        OfflineReadinessItemType.connectivityRiskAnalysis,
        OfflineReadinessItemType.offlineMap,
      }),
    );

    final offlineMap = result.assessment.items.singleWhere(
      (item) => item.type == OfflineReadinessItemType.offlineMap,
    );

    expect(offlineMap.isRequired, isTrue);
    expect(offlineMap.status, OfflineReadinessItemStatus.notApplicable);
    expect(result.assessment.score, lessThan(1));
    expect(result.assessment.level, OfflineReadinessLevel.needsAttention);
  });

  test('unsupported capabilities stay not applicable when not escalated', () {
    final result = evaluator.evaluate(
      snapshot: snapshot(pois: const [poi], connectivity: connectivity()),
    );

    final emergency = result.assessment.items.singleWhere(
      (item) => item.type == OfflineReadinessItemType.emergencyInfo,
    );

    final map = result.assessment.items.singleWhere(
      (item) => item.type == OfflineReadinessItemType.offlineMap,
    );

    expect(emergency.status, OfflineReadinessItemStatus.notApplicable);
    expect(map.status, OfflineReadinessItemStatus.notApplicable);
    expect(emergency.isRequired, isFalse);
    expect(map.isRequired, isFalse);
  });

  test('preserves assessment timestamp', () {
    final assessedAt = DateTime.utc(2026, 10, 25, 5);

    final result = evaluator.evaluate(
      snapshot: snapshot(pois: const [poi], connectivity: connectivity()),
      assessedAt: assessedAt,
    );

    expect(result.assessment.assessedAt, assessedAt);
  });
}
