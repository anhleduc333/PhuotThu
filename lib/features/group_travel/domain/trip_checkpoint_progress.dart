import 'trip_checkpoint.dart';
import 'trip_checkpoint_arrival.dart';

/// Pure domain summary. Only active member IDs count towards progress.
/// Realtime subscription and UI will be added in later DEV-09.7 milestones.
class TripCheckpointProgress {
  TripCheckpointProgress({
    required this.checkpoint,
    required Iterable<String> activeUserIds,
    required Iterable<TripCheckpointArrival> arrivals,
  }) : activeUserIds = Set<String>.unmodifiable(activeUserIds),
       arrivedUserIds = Set<String>.unmodifiable(
         arrivals
             .where((arrival) => arrival.checkpointId == checkpoint.id)
             .map((arrival) => arrival.userId)
             .where((userId) => activeUserIds.contains(userId)),
       );

  final TripCheckpoint checkpoint;
  final Set<String> activeUserIds;
  final Set<String> arrivedUserIds;

  int get memberCount => activeUserIds.length;
  int get arrivedCount => arrivedUserIds.length;
  int get pendingCount => memberCount - arrivedCount;
  bool get allArrived => memberCount > 0 && pendingCount == 0;
  double get completionRatio =>
      memberCount == 0 ? 0 : arrivedCount / memberCount;
  Set<String> get pendingUserIds =>
      Set<String>.unmodifiable(activeUserIds.difference(arrivedUserIds));
  bool hasArrived(String userId) => arrivedUserIds.contains(userId);
}
