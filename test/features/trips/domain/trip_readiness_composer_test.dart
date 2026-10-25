import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk.dart';
import 'package:phuotthu/features/trips/domain/emergency_readiness.dart';
import 'package:phuotthu/features/trips/domain/offline_readiness.dart';
import 'package:phuotthu/features/trips/domain/personal_readiness.dart';
import 'package:phuotthu/features/trips/domain/route_weather_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness_checklist_snapshot.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness_composer.dart';
import 'package:phuotthu/features/trips/domain/vehicle_readiness.dart';
import 'package:phuotthu/features/vehicle/domain/vehicle.dart';

void main() {
  const composer = TripReadinessComposer();

  Vehicle vehicle() {
    return const Vehicle(
      id: 'vehicle-1',
      userId: 'user-1',
      name: 'Xe test',
      vehicleType: 'motorbike',
      brand: 'Test',
      model: 'Model',
      plateNumber: '30A-000.00',
      fuelType: 'gasoline',
      fuelTankCapacityL: 15,
      consumptionLPer100Km: 3,
      batteryCapacityKwh: null,
      isDefault: true,
    );
  }

  OfflineReadinessAssessment offline({
    OfflineReadinessLevel level = OfflineReadinessLevel.ready,
    double score = 1,
  }) {
    return OfflineReadinessAssessment(
      level: level,
      score: score,
      items: const [],
    );
  }

  ConnectivityRiskAssessment connectivity() {
    return const ConnectivityRiskAssessment(
      totalRouteMeters: 100000,
      overallRiskScore: 0.3,
      overallLevel: ConnectivityRiskLevel.moderate,
      segments: [
        ConnectivityRiskSegment(
          startDistanceMeters: 0,
          endDistanceMeters: 100000,
          startProgressRatio: 0,
          endProgressRatio: 1,
          averageRiskScore: 0.3,
          maxRiskScore: 0.4,
          level: ConnectivityRiskLevel.moderate,
          sampleCount: 3,
        ),
      ],
    );
  }

  TripReadinessChecklistSnapshot completeChecklist() {
    return TripReadinessChecklistSnapshot(
      schemaVersion: 1,
      tripId: 'trip-1',
      updatedAt: DateTime.utc(2026, 10, 25),
      vehicle: const VehicleReadinessConfirmations(
        fuelOrEnergyReady: true,
        mechanicalConditionOk: true,
        tiresOk: true,
        documentsAvailable: true,
      ),
      personal: const PersonalReadinessConfirmations(
        protectiveGearReady: true,
        personalEssentialsReady: true,
      ),
      routeWeather: const RouteWeatherReadinessConfirmations(
        routeReviewed: true,
        weatherReviewed: true,
      ),
      emergency: const EmergencyReadinessConfirmations(
        emergencyContactsReady: true,
        sosPlanReviewed: true,
        firstAidKitReady: true,
      ),
    );
  }

  test('complete data across five categories is ready', () {
    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: completeChecklist(),
      vehicle: vehicle(),
      hasRoute: true,
      connectivityAssessment: connectivity(),
    );

    expect(result.scoring.assessment.level, TripReadinessLevel.ready);
    expect(result.scoring.assessment.score, 1);
    expect(result.scoring.assessment.categorySummaries.length, 5);
  });

  test('missing vehicle hard-blocks total readiness', () {
    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: completeChecklist(),
      vehicle: null,
      hasRoute: true,
      connectivityAssessment: connectivity(),
    );

    expect(result.scoring.assessment.level, TripReadinessLevel.notReady);
    expect(result.vehicle.hasVehicle, isFalse);
    expect(result.vehicle.blockingItems.length, 4);
  });

  test('offline needs attention prevents total READY', () {
    final result = composer.compose(
      offlineAssessment: offline(
        level: OfflineReadinessLevel.needsAttention,
        score: 0.92,
      ),
      checklist: completeChecklist(),
      vehicle: vehicle(),
      hasRoute: true,
      connectivityAssessment: connectivity(),
    );

    expect(result.scoring.assessment.level, TripReadinessLevel.needsAttention);

    final offlineSummary = result.scoring.assessment.summaryForCategory(
      TripReadinessCategory.offline,
    );

    expect(offlineSummary, isNotNull);
    expect(offlineSummary!.score, closeTo(0.92, 0.0001));

    // 20% * 92% + 80% * 100% = 98.4%.
    expect(result.scoring.assessment.score, closeTo(0.984, 0.0001));
  });

  test('missing route hard-blocks readiness', () {
    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: completeChecklist(),
      vehicle: vehicle(),
      hasRoute: false,
      connectivityAssessment: connectivity(),
    );

    expect(result.scoring.assessment.level, TripReadinessLevel.notReady);
    expect(result.routeWeather.hasRoute, isFalse);
  });

  test('missing connectivity assessment keeps route category not ready', () {
    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: completeChecklist(),
      vehicle: vehicle(),
      hasRoute: true,
    );

    final item = result.scoring.assessment.items.singleWhere(
      (item) => item.type == TripReadinessItemType.connectivityReviewed,
    );

    expect(item.status, TripReadinessItemStatus.unknown);
    expect(result.scoring.assessment.level, TripReadinessLevel.notReady);
  });

  test('personal negative confirmation becomes needs attention', () {
    final base = completeChecklist();

    final checklist = base.copyWith(
      personal: const PersonalReadinessConfirmations(
        protectiveGearReady: false,
        personalEssentialsReady: true,
      ),
    );

    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: checklist,
      vehicle: vehicle(),
      hasRoute: true,
      connectivityAssessment: connectivity(),
    );

    expect(
      result.personal.actionItems.single.type,
      TripReadinessItemType.personalProtectiveGear,
    );
    expect(result.scoring.assessment.level, TripReadinessLevel.needsAttention);
  });

  test('missing emergency contacts hard-blocks readiness', () {
    final base = completeChecklist();

    final checklist = base.copyWith(
      emergency: const EmergencyReadinessConfirmations(
        emergencyContactsReady: false,
        sosPlanReviewed: true,
        firstAidKitReady: true,
      ),
    );

    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: checklist,
      vehicle: vehicle(),
      hasRoute: true,
      connectivityAssessment: connectivity(),
    );

    expect(result.emergency.blockingItems.length, 1);
    expect(result.scoring.assessment.level, TripReadinessLevel.notReady);
  });

  test('preserves assessment timestamp through aggregate scorer', () {
    final assessedAt = DateTime.parse('2026-10-25T16:00:00+07:00');

    final result = composer.compose(
      offlineAssessment: offline(),
      checklist: completeChecklist(),
      vehicle: vehicle(),
      hasRoute: true,
      connectivityAssessment: connectivity(),
      assessedAt: assessedAt,
    );

    expect(result.scoring.assessment.assessedAt, isNotNull);
    expect(result.scoring.assessment.assessedAt!.isUtc, isTrue);
    expect(result.scoring.assessment.assessedAt!.hour, 9);
  });
}
