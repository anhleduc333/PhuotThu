import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/emergency_readiness.dart';
import 'package:phuotthu/features/trips/domain/trip_readiness.dart';

void main() {
  const evaluator = EmergencyReadinessEvaluator();

  group('EmergencyReadinessEvaluator', () {
    test('starts with all emergency items unchecked', () {
      final result = evaluator.evaluate();

      expect(result.items.length, 3);
      expect(result.uncheckedItems.length, 3);
      expect(result.readyCount, 0);
      expect(result.allRequiredReady, isFalse);
    });

    test('all positive confirmations make emergency checklist ready', () {
      final result = evaluator.evaluate(
        confirmations: const EmergencyReadinessConfirmations(
          emergencyContactsReady: true,
          sosPlanReviewed: true,
          firstAidKitReady: true,
        ),
      );

      expect(result.readyCount, 3);
      expect(result.actionItems, isEmpty);
      expect(result.blockingItems, isEmpty);
      expect(result.allRequiredReady, isTrue);
    });

    test('missing emergency contacts creates hard block', () {
      final result = evaluator.evaluate(
        confirmations: const EmergencyReadinessConfirmations(
          emergencyContactsReady: false,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.emergencyContacts,
      );

      expect(item.status, TripReadinessItemStatus.missing);
      expect(item.blocksReadiness, isTrue);
      expect(item.preventsReady, isTrue);
    });

    test('unprepared SOS plan needs attention but is not hard block', () {
      final result = evaluator.evaluate(
        confirmations: const EmergencyReadinessConfirmations(
          sosPlanReviewed: false,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.sosPrepared,
      );

      expect(item.status, TripReadinessItemStatus.needsAttention);
      expect(item.blocksReadiness, isFalse);
      expect(item.preventsReady, isTrue);
    });

    test('missing first aid preparation needs attention', () {
      final result = evaluator.evaluate(
        confirmations: const EmergencyReadinessConfirmations(
          firstAidKitReady: false,
        ),
      );

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.firstAidKit,
      );

      expect(item.status, TripReadinessItemStatus.needsAttention);
      expect(item.blocksReadiness, isFalse);
      expect(item.preventsReady, isTrue);
    });

    test('all items are required emergency preparation items', () {
      final result = evaluator.evaluate();

      expect(
        result.items.every(
          (item) =>
              item.isRequired &&
              item.category == TripReadinessCategory.emergency &&
              item.source == TripReadinessSourceType.emergencyPlan,
        ),
        isTrue,
      );
    });

    test('partial confirmations leave remaining items unknown', () {
      final result = evaluator.evaluate(
        confirmations: const EmergencyReadinessConfirmations(
          emergencyContactsReady: true,
        ),
      );

      final contacts = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.emergencyContacts,
      );

      expect(contacts.status, TripReadinessItemStatus.ready);
      expect(result.uncheckedItems.length, 2);
    });

    test('confirmation completeness requires all three answers', () {
      const empty = EmergencyReadinessConfirmations();

      const partial = EmergencyReadinessConfirmations(
        emergencyContactsReady: true,
        sosPlanReviewed: true,
      );

      const complete = EmergencyReadinessConfirmations(
        emergencyContactsReady: true,
        sosPlanReviewed: true,
        firstAidKitReady: false,
      );

      expect(empty.isComplete, isFalse);
      expect(partial.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
    });

    test('checkedAt is normalized to UTC', () {
      final checkedAt = DateTime.parse('2026-10-25T13:15:00+07:00');

      final result = evaluator.evaluate(
        confirmations: EmergencyReadinessConfirmations(
          emergencyContactsReady: true,
          sosPlanReviewed: true,
          firstAidKitReady: true,
          checkedAt: checkedAt,
        ),
      );

      expect(
        result.items.every(
          (item) => item.lastCheckedAt != null && item.lastCheckedAt!.isUtc,
        ),
        isTrue,
      );
      expect(result.items.first.lastCheckedAt!.hour, 6);
      expect(result.items.first.lastCheckedAt!.minute, 15);
    });

    test('safety notice does not claim automatic rescue', () {
      expect(
        EmergencyReadinessEvaluation.safetyNotice,
        contains('không phải hệ thống cứu hộ'),
      );
      expect(
        EmergencyReadinessEvaluation.safetyNotice,
        contains('không cam kết tự động'),
      );
    });

    test('SOS description explicitly avoids rescue dispatch claim', () {
      final result = evaluator.evaluate();

      final item = result.items.singleWhere(
        (item) => item.type == TripReadinessItemType.sosPrepared,
      );

      expect(item.description, contains('không tự động điều phối cứu hộ'));
    });

    test('action items contain only answered negative checks', () {
      final result = evaluator.evaluate(
        confirmations: const EmergencyReadinessConfirmations(
          emergencyContactsReady: true,
          sosPlanReviewed: false,
          firstAidKitReady: false,
        ),
      );

      expect(result.actionItems.length, 2);
      expect(
        result.actionItems.map((item) => item.type),
        containsAll({
          TripReadinessItemType.sosPrepared,
          TripReadinessItemType.firstAidKit,
        }),
      );
    });
  });
}
