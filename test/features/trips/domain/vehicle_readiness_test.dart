import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';
import 'package:phuotthu/features/trips/domain/vehicle_readiness.dart';
import 'package:phuotthu/features/vehicle/domain/vehicle.dart';

void main() {
  const evaluator = VehicleReadinessEvaluator();

  Vehicle vehicle({
    String? fuelType = 'gasoline',
    double? tank = 50,
    double? consumption = 6.5,
    double? battery,
  }) {
    return Vehicle(
      id: 'vehicle-1',
      userId: 'user-1',
      name: 'Xe test',
      vehicleType: 'motorbike',
      brand: 'Test',
      model: 'Model',
      plateNumber: '30A-000.00',
      fuelType: fuelType,
      fuelTankCapacityL: tank,
      consumptionLPer100Km: consumption,
      batteryCapacityKwh: battery,
      isDefault: true,
    );
  }

  group('VehicleReadinessEvaluator', () {
    test('no vehicle produces four blocking required items', () {
      final result = evaluator.evaluate(vehicle: null);

      expect(result.hasVehicle, isFalse);
      expect(result.hasProfileIssues, isTrue);
      expect(
        result.profileIssues.single.type,
        VehicleReadinessProfileIssueType.noVehicle,
      );
      expect(result.items.length, 4);
      expect(result.blockingItems.length, 4);
      expect(
        result.items.every(
          (item) =>
              item.status == TripReadinessItemStatus.missing && item.isRequired,
        ),
        isTrue,
      );
    });

    test('selected vehicle starts with manual items unchecked', () {
      final result = evaluator.evaluate(vehicle: vehicle());

      expect(result.hasVehicle, isTrue);
      expect(result.hasProfileIssues, isFalse);
      expect(result.uncheckedItems.length, 4);
      expect(result.allRequiredReady, isFalse);
    });

    test('all positive confirmations make vehicle checklist ready', () {
      final checkedAt = DateTime.utc(2026, 10, 25, 4);

      final result = evaluator.evaluate(
        vehicle: vehicle(),
        confirmations: VehicleReadinessConfirmations(
          fuelOrEnergyReady: true,
          mechanicalConditionOk: true,
          tiresOk: true,
          documentsAvailable: true,
          checkedAt: checkedAt,
        ),
      );

      expect(result.readyCount, 4);
      expect(result.allRequiredReady, isTrue);
      expect(result.actionItems, isEmpty);
      expect(
        result.items.every((item) => item.lastCheckedAt == checkedAt),
        isTrue,
      );
    });

    test('negative fuel confirmation needs attention', () {
      final result = evaluator.evaluate(
        vehicle: vehicle(),
        confirmations: const VehicleReadinessConfirmations(
          fuelOrEnergyReady: false,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.vehicleFuelOrEnergy,
      );

      expect(item.status, TripReadinessItemStatus.needsAttention);
      expect(item.blocksReadiness, isFalse);
      expect(item.preventsReady, isTrue);
    });

    test('missing documents are a blocking item', () {
      final result = evaluator.evaluate(
        vehicle: vehicle(),
        confirmations: const VehicleReadinessConfirmations(
          documentsAvailable: false,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.vehicleDocuments,
      );

      expect(item.status, TripReadinessItemStatus.missing);
      expect(item.blocksReadiness, isTrue);
    });

    test('reports missing liquid-fuel profile fields', () {
      final result = evaluator.evaluate(
        vehicle: vehicle(tank: null, consumption: null),
      );

      expect(
        result.profileIssues.map((issue) => issue.type),
        containsAll({
          VehicleReadinessProfileIssueType.missingFuelTankCapacity,
          VehicleReadinessProfileIssueType.missingFuelConsumption,
        }),
      );
    });

    test('reports missing fuel type and stops dependent checks', () {
      final result = evaluator.evaluate(
        vehicle: vehicle(fuelType: null, tank: null, consumption: null),
      );

      expect(result.profileIssues.length, 1);
      expect(
        result.profileIssues.single.type,
        VehicleReadinessProfileIssueType.missingFuelType,
      );
    });

    test('electric vehicle checks battery capacity profile', () {
      final missingBattery = evaluator.evaluate(
        vehicle: vehicle(
          fuelType: 'electric',
          tank: null,
          consumption: null,
          battery: null,
        ),
      );

      expect(
        missingBattery.profileIssues.single.type,
        VehicleReadinessProfileIssueType.missingBatteryCapacity,
      );

      final completeBattery = evaluator.evaluate(
        vehicle: vehicle(
          fuelType: 'electric',
          tank: null,
          consumption: null,
          battery: 60,
        ),
      );

      expect(completeBattery.profileIssues, isEmpty);
    });

    test('does not infer current fuel or battery state from profile', () {
      final liquid = evaluator.evaluate(vehicle: vehicle());

      final electric = evaluator.evaluate(
        vehicle: vehicle(
          fuelType: 'electric',
          tank: null,
          consumption: null,
          battery: 60,
        ),
      );

      final liquidFuel = liquid.items.singleWhere(
        (item) => item.type == TripReadinessItemType.vehicleFuelOrEnergy,
      );

      final electricEnergy = electric.items.singleWhere(
        (item) => item.type == TripReadinessItemType.vehicleFuelOrEnergy,
      );

      expect(liquidFuel.status, TripReadinessItemStatus.unknown);
      expect(electricEnergy.status, TripReadinessItemStatus.unknown);
    });

    test('confirmation completeness requires all four answers', () {
      const incomplete = VehicleReadinessConfirmations(
        fuelOrEnergyReady: true,
        mechanicalConditionOk: true,
        tiresOk: true,
      );

      const complete = VehicleReadinessConfirmations(
        fuelOrEnergyReady: true,
        mechanicalConditionOk: true,
        tiresOk: true,
        documentsAvailable: true,
      );

      expect(incomplete.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });

    test('vehicle items belong to vehicle category', () {
      final result = evaluator.evaluate(vehicle: vehicle());

      expect(
        result.items.every(
          (item) => item.category == TripReadinessCategory.vehicle,
        ),
        isTrue,
      );
    });

    test('checkedAt is normalized to UTC', () {
      final localLike = DateTime.parse('2026-10-25T10:00:00+07:00');

      final result = evaluator.evaluate(
        vehicle: vehicle(),
        confirmations: VehicleReadinessConfirmations(
          fuelOrEnergyReady: true,
          checkedAt: localLike,
        ),
      );

      final checked = result.items.first.lastCheckedAt;

      expect(checked, isNotNull);
      expect(checked!.isUtc, isTrue);
      expect(checked.hour, 3);
    });
  });
}
