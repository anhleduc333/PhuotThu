import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/personal_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';

void main() {
  const evaluator = PersonalReadinessEvaluator();

  group('PersonalReadinessEvaluator', () {
    test('starts with both items unchecked', () {
      final result = evaluator.evaluate();

      expect(result.items.length, 2);
      expect(result.uncheckedItems.length, 2);
      expect(result.readyCount, 0);
      expect(result.allRequiredReady, isFalse);
    });

    test('all positive confirmations make checklist ready', () {
      final result = evaluator.evaluate(
        confirmations: const PersonalReadinessConfirmations(
          protectiveGearReady: true,
          personalEssentialsReady: true,
        ),
      );

      expect(result.readyCount, 2);
      expect(result.actionItems, isEmpty);
      expect(result.allRequiredReady, isTrue);
    });

    test('negative protective gear confirmation needs attention', () {
      final result = evaluator.evaluate(
        confirmations: const PersonalReadinessConfirmations(
          protectiveGearReady: false,
          personalEssentialsReady: true,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.personalProtectiveGear,
      );

      expect(item.status, TripReadinessItemStatus.needsAttention);
      expect(item.requiresAction, isTrue);
      expect(item.blocksReadiness, isFalse);
      expect(item.preventsReady, isTrue);
    });

    test('negative essentials confirmation needs attention', () {
      final result = evaluator.evaluate(
        confirmations: const PersonalReadinessConfirmations(
          protectiveGearReady: true,
          personalEssentialsReady: false,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.personalEssentials,
      );

      expect(item.status, TripReadinessItemStatus.needsAttention);
      expect(item.preventsReady, isTrue);
    });

    test('items are required manual personal checks', () {
      final result = evaluator.evaluate();

      expect(
        result.items.every(
          (item) =>
              item.isRequired &&
              item.source == TripReadinessSourceType.manual &&
              item.category == TripReadinessCategory.personal,
        ),
        isTrue,
      );
    });

    test('confirmation completeness requires both answers', () {
      const empty = PersonalReadinessConfirmations();

      const partial = PersonalReadinessConfirmations(protectiveGearReady: true);

      const complete = PersonalReadinessConfirmations(
        protectiveGearReady: true,
        personalEssentialsReady: false,
      );

      expect(empty.isComplete, isFalse);
      expect(partial.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });

    test('checkedAt is normalized to UTC', () {
      final localLike = DateTime.parse('2026-10-25T10:30:00+07:00');

      final result = evaluator.evaluate(
        confirmations: PersonalReadinessConfirmations(
          protectiveGearReady: true,
          personalEssentialsReady: true,
          checkedAt: localLike,
        ),
      );

      expect(
        result.items.every(
          (item) => item.lastCheckedAt != null && item.lastCheckedAt!.isUtc,
        ),
        isTrue,
      );

      expect(result.items.first.lastCheckedAt!.hour, 3);
      expect(result.items.first.lastCheckedAt!.minute, 30);
    });

    test('partial confirmation keeps remaining item unknown', () {
      final result = evaluator.evaluate(
        confirmations: const PersonalReadinessConfirmations(
          protectiveGearReady: true,
        ),
      );

      final gear = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.personalProtectiveGear,
      );

      final essentials = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.personalEssentials,
      );

      expect(gear.status, TripReadinessItemStatus.ready);
      expect(essentials.status, TripReadinessItemStatus.unknown);
      expect(result.uncheckedItems.length, 1);
    });

    test('descriptions do not claim automatic verification', () {
      final result = evaluator.evaluate();

      expect(
        result.items.every(
          (item) => item.description != null && item.description!.isNotEmpty,
        ),
        isTrue,
      );

      final gear = result.items.first.description!;
      expect(gear.contains('người dùng xác nhận'), isTrue);
    });

    test('actionItems only contains negative confirmations', () {
      final result = evaluator.evaluate(
        confirmations: const PersonalReadinessConfirmations(
          protectiveGearReady: false,
          personalEssentialsReady: true,
        ),
      );

      expect(result.actionItems.length, 1);
      expect(
        result.actionItems.single.type,
        TripReadinessItemType.personalProtectiveGear,
      );
    });
  });
}
