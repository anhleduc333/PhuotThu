import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/fuel_range_calculator.dart';

void main() {
  const calculator = FuelRangeCalculator();

  group('FuelRangeCalculator', () {
    test('calculates theoretical and safe range correctly', () {
      final result = calculator.calculate(
        tankCapacityLiters: 15,
        consumptionLitersPer100Km: 6.5,
      );

      expect(result, isNotNull);

      expect(result!.startingFuelLiters, closeTo(15, 0.001));

      expect(result.reserveFuelLiters, closeTo(3.75, 0.001));

      expect(result.usableFuelLiters, closeTo(11.25, 0.001));

      expect(result.theoreticalRangeKm, closeTo(230.769, 0.01));

      expect(result.safeRangeKm, closeTo(173.077, 0.01));

      expect(result.reserveRangeKm, closeTo(57.692, 0.01));
    });

    test('detects when a fuel stop is required', () {
      final result = calculator.calculate(
        tankCapacityLiters: 15,
        consumptionLitersPer100Km: 6.5,
      );

      expect(result, isNotNull);

      expect(result!.needsFuelStopForDistanceMeters(420000), isTrue);

      expect(result.canSafelyCoverDistanceMeters(150000), isTrue);
    });

    test('supports a partially filled starting tank', () {
      final result = calculator.calculate(
        tankCapacityLiters: 20,
        consumptionLitersPer100Km: 5,
        startingFuelRatio: 0.5,
        reserveRatio: 0.2,
      );

      expect(result, isNotNull);

      expect(result!.startingFuelLiters, closeTo(10, 0.001));

      expect(result.reserveFuelLiters, closeTo(4, 0.001));

      expect(result.usableFuelLiters, closeTo(6, 0.001));

      expect(result.safeRangeKm, closeTo(120, 0.001));
    });

    test('safe range becomes zero when starting fuel is below reserve', () {
      final result = calculator.calculate(
        tankCapacityLiters: 20,
        consumptionLitersPer100Km: 5,
        startingFuelRatio: 0.1,
        reserveRatio: 0.25,
      );

      expect(result, isNotNull);

      expect(result!.usableFuelLiters, 0);

      expect(result.safeRangeKm, 0);

      expect(result.needsFuelStopForDistanceMeters(1000), isTrue);
    });

    test('returns null for missing tank capacity', () {
      expect(
        calculator.calculate(
          tankCapacityLiters: null,
          consumptionLitersPer100Km: 6.5,
        ),
        isNull,
      );
    });

    test('returns null for invalid tank capacity', () {
      expect(
        calculator.calculate(
          tankCapacityLiters: 0,
          consumptionLitersPer100Km: 6.5,
        ),
        isNull,
      );
    });

    test('returns null for missing consumption', () {
      expect(
        calculator.calculate(
          tankCapacityLiters: 15,
          consumptionLitersPer100Km: null,
        ),
        isNull,
      );
    });

    test('returns null for invalid consumption', () {
      expect(
        calculator.calculate(
          tankCapacityLiters: 15,
          consumptionLitersPer100Km: 0,
        ),
        isNull,
      );
    });

    test('returns null for invalid starting fuel ratio', () {
      expect(
        calculator.calculate(
          tankCapacityLiters: 15,
          consumptionLitersPer100Km: 6.5,
          startingFuelRatio: 1.1,
        ),
        isNull,
      );

      expect(
        calculator.calculate(
          tankCapacityLiters: 15,
          consumptionLitersPer100Km: 6.5,
          startingFuelRatio: -0.1,
        ),
        isNull,
      );
    });

    test('returns null for invalid reserve ratio', () {
      expect(
        calculator.calculate(
          tankCapacityLiters: 15,
          consumptionLitersPer100Km: 6.5,
          reserveRatio: 1,
        ),
        isNull,
      );

      expect(
        calculator.calculate(
          tankCapacityLiters: 15,
          consumptionLitersPer100Km: 6.5,
          reserveRatio: -0.1,
        ),
        isNull,
      );
    });
  });
}
