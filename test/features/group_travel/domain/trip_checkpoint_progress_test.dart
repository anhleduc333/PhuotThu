import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_checkpoint.dart';
import 'package:phuotthu/features/group_travel/domain/trip_checkpoint_arrival.dart';
import 'package:phuotthu/features/group_travel/domain/trip_checkpoint_progress.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26);
  final checkpoint = TripCheckpoint(
    id: 'cp-1',
    tripId: 'trip-1',
    name: 'Checkpoint 1',
    latitude: 21,
    longitude: 105,
    radiusM: 100,
    sortOrder: 0,
    isRequired: true,
    autoArrivalEnabled: true,
    createdAt: now,
    updatedAt: now,
  );

  TripCheckpointArrival arrival(String cp, String user) =>
      TripCheckpointArrival(
        checkpointId: cp,
        userId: user,
        arrivedAt: now,
        method: TripCheckpointArrivalMethod.manual,
      );

  test('counts only arrived active members for this checkpoint', () {
    final progress = TripCheckpointProgress(
      checkpoint: checkpoint,
      activeUserIds: ['owner', 'member-b', 'member-c'],
      arrivals: [
        arrival('cp-1', 'owner'),
        arrival('cp-1', 'member-b'),
        arrival('cp-1', 'removed-user'),
        arrival('cp-2', 'member-c'),
      ],
    );
    expect(progress.memberCount, 3);
    expect(progress.arrivedCount, 2);
    expect(progress.pendingCount, 1);
    expect(progress.pendingUserIds, {'member-c'});
    expect(progress.completionRatio, closeTo(2 / 3, 0.00001));
    expect(progress.allArrived, isFalse);
  });

  test('fully arrived and empty groups are distinct', () {
    final complete = TripCheckpointProgress(
      checkpoint: checkpoint,
      activeUserIds: ['owner'],
      arrivals: [arrival('cp-1', 'owner')],
    );
    expect(complete.allArrived, isTrue);
    expect(complete.completionRatio, 1);

    final empty = TripCheckpointProgress(
      checkpoint: checkpoint,
      activeUserIds: [],
      arrivals: [],
    );
    expect(empty.allArrived, isFalse);
    expect(empty.completionRatio, 0);
  });
}
