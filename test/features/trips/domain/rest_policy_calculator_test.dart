import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/rest_policy_calculator.dart';

void main() {
  const calculator = RestPolicyCalculator();

  group('RestPolicyCalculator', () {
    test('uses distance trigger when 100 km occurs before 90 minutes', () {
      final plan = calculator.calculate(
        distanceMeters: 300000,
        durationSeconds: 4 * 60 * 60,
      );

      expect(plan, isNotNull);

      expect(plan!.recommendedStopCount, 2);

      expect(plan.targets[0].trigger, RestTrigger.distance);

      expect(plan.targets[0].targetDistanceKm, closeTo(100, 0.1));

      expect(plan.targets[1].targetDistanceKm, closeTo(200, 0.1));
    });

    test('uses time trigger on a slower route', () {
      final plan = calculator.calculate(
        distanceMeters: 200000,
        durationSeconds: 4 * 60 * 60,
      );

      expect(plan, isNotNull);

      expect(plan!.targets, isNotEmpty);

      expect(plan.targets.first.trigger, RestTrigger.time);

      expect(plan.targets.first.targetElapsedMinutes, closeTo(90, 0.1));

      expect(plan.targets.first.targetDistanceKm, closeTo(75, 0.1));
    });

    test('reports both triggers when time and distance thresholds align', () {
      final plan = calculator.calculate(
        distanceMeters: 200000,
        durationSeconds: 3 * 60 * 60,
      );

      expect(plan, isNotNull);

      expect(plan!.recommendedStopCount, 1);

      expect(plan.targets.first.trigger, RestTrigger.both);

      expect(plan.targets.first.targetDistanceKm, closeTo(100, 0.1));

      expect(plan.targets.first.targetElapsedMinutes, closeTo(90, 0.1));
    });

    test('does not recommend a stop for a short trip', () {
      final plan = calculator.calculate(
        distanceMeters: 80000,
        durationSeconds: 60 * 60,
      );

      expect(plan, isNotNull);

      expect(plan!.restRecommended, isFalse);

      expect(plan.targets, isEmpty);
    });

    test('does not create a final stop immediately before destination', () {
      final plan = calculator.calculate(
        distanceMeters: 210000,
        durationSeconds: 3 * 60 * 60 + 10 * 60,
      );

      expect(plan, isNotNull);

      expect(
        plan!.targets.last.targetDistanceMeters,
        lessThan(plan.totalDistanceMeters),
      );

      final lastTarget = plan.targets.last;

      final remainingDistance =
          plan.totalDistanceMeters - lastTarget.targetDistanceMeters;

      expect(remainingDistance, greaterThanOrEqualTo(20000));
    });

    test('supports a custom rest policy', () {
      const policy = RestPolicy(
        driveIntervalMinutes: 60,
        distanceIntervalKm: 80,
        suggestedRestMinutes: 20,
      );

      final plan = calculator.calculate(
        distanceMeters: 240000,
        durationSeconds: 4 * 60 * 60,
        policy: policy,
      );

      expect(plan, isNotNull);

      expect(plan!.targets, isNotEmpty);

      expect(plan.targets.first.targetElapsedMinutes, closeTo(60, 0.1));

      expect(plan.targets.first.suggestedRestMinutes, 20);
    });

    test('respects maximum number of stops', () {
      const policy = RestPolicy(
        driveIntervalMinutes: 30,
        distanceIntervalKm: 30,
        maxStops: 3,
      );

      final plan = calculator.calculate(
        distanceMeters: 1000000,
        durationSeconds: 20 * 60 * 60,
        policy: policy,
      );

      expect(plan, isNotNull);

      expect(plan!.recommendedStopCount, 3);
    });

    test('returns null for invalid route values', () {
      expect(
        calculator.calculate(distanceMeters: 0, durationSeconds: 3600),
        isNull,
      );

      expect(
        calculator.calculate(distanceMeters: 100000, durationSeconds: 0),
        isNull,
      );
    });

    test('returns null for invalid policy', () {
      const invalidPolicy = RestPolicy(driveIntervalMinutes: 0);

      expect(
        calculator.calculate(
          distanceMeters: 100000,
          durationSeconds: 7200,
          policy: invalidPolicy,
        ),
        isNull,
      );
    });
  });
}
