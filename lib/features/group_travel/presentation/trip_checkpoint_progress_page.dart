import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_trip_providers.dart';
import '../data/trip_checkpoint_providers.dart';
import '../data/trip_live_location_providers.dart';
import '../domain/trip_checkpoint_progress.dart';
import '../domain/trip_live_location.dart';
import '../domain/trip_member_view.dart';

/// DEV-09.7E/F: group checkpoint progress. Refreshes every 10 seconds;
/// the live-position markers are already streamed through Supabase Realtime.
class TripCheckpointProgressPage extends ConsumerStatefulWidget {
  const TripCheckpointProgressPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripCheckpointProgressPage> createState() =>
      _TripCheckpointProgressPageState();
}

class _TripCheckpointProgressPageState
    extends ConsumerState<TripCheckpointProgressPage> {
  Timer? _timer;
  String? _submittingCheckpointId;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  void _refresh() {
    ref.invalidate(tripCheckpointsProvider(widget.tripId));
    ref.invalidate(tripCheckpointArrivalsProvider(widget.tripId));
    ref.invalidate(tripCheckpointProgressProvider(widget.tripId));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmArrival(
    TripCheckpointProgress progress,
    String viewerId,
  ) async {
    final checkpointId = progress.checkpoint.id;
    if (_submittingCheckpointId != null || progress.hasArrived(viewerId)) {
      return;
    }
    setState(() => _submittingCheckpointId = checkpointId);
    try {
      await ref
          .read(tripCheckpointRepositoryProvider)
          .confirmMyArrival(checkpointId);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận đến điểm hẹn.')),
        );
      }
    } catch (error) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Chưa thể xác nhận: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _submittingCheckpointId = null);
      }
    }
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  String _remainingInfo(
    TripCheckpointProgress progress,
    TripLiveLocation? location,
  ) {
    if (location == null ||
        !location.isFreshAt(
          DateTime.now(),
          freshnessWindow: const Duration(seconds: 90),
        )) {
      return 'Chưa có GPS gần đây';
    }
    final meters = _distanceMeters(
      location.latitude,
      location.longitude,
      progress.checkpoint.latitude,
      progress.checkpoint.longitude,
    );
    final distanceLabel = meters < 1000
        ? '${meters.round()} m đường chim bay'
        : '${(meters / 1000).toStringAsFixed(1)} km đường chim bay';
    final speed = location.speedMetersPerSecond;
    if (speed == null || speed < 1 || meters / speed > 14400) {
      return distanceLabel;
    }
    // Straight-line only. Not a navigational/road ETA.
    final minutes = (meters / speed / 60).ceil();
    return '$distanceLabel • ~${minutes < 1 ? 1 : minutes} phút (ước tính thô)';
  }

  Widget _progressList(
    List<TripCheckpointProgress> progresses,
    List<TripMemberView> members,
    List<TripLiveLocation> locations,
    String viewerId,
  ) {
    final byMember = {for (final member in members) member.userId: member};
    final byLocation = {for (final item in locations) item.userId: item};
    if (progresses.isEmpty) {
      return const Center(child: Text('Chưa có điểm hẹn để theo dõi tiến độ.'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await ref.read(tripCheckpointProgressProvider(widget.tripId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          for (final progress in progresses)
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      progress.checkpoint.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${progress.arrivedCount}/${progress.memberCount} '
                      'thành viên đã đến',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress.completionRatio),
                    const SizedBox(height: 8),
                    for (final userId in progress.activeUserIds) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          progress.hasArrived(userId)
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: progress.hasArrived(userId)
                              ? Colors.green.shade700
                              : null,
                        ),
                        title: Text(
                          byMember[userId]?.displayName ??
                              (userId == viewerId ? 'Bạn' : 'Thành viên'),
                        ),
                        subtitle: Text(
                          progress.hasArrived(userId)
                              ? 'Đã tới điểm hẹn'
                              : _remainingInfo(progress, byLocation[userId]),
                        ),
                      ),
                    ],
                    if (!progress.hasArrived(viewerId)) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _submittingCheckpointId != null
                            ? null
                            : () => _confirmArrival(progress, viewerId),
                        icon: const Icon(Icons.how_to_reg_outlined),
                        label: const Text('Tôi đã đến (xác nhận thủ công)'),
                      ),
                    ],
                    if (progress.allArrived)
                      const Text(
                        'Toàn đoàn đã tới điểm hẹn.',
                        style: TextStyle(color: Colors.green),
                      ),
                  ],
                ),
              ),
            ),
          const Text(
            'GPS tự động chỉ ghi nhận khi đã bật chia sẻ vị trí, tín hiệu '
            'còn mới và đủ chính xác. Khoảng cách/ETA hiển thị là ước lượng '
            'đường chim bay, không phải thời gian theo tuyến đường.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupTripStateProvider(widget.tripId));
    final progressAsync = ref.watch(
      tripCheckpointProgressProvider(widget.tripId),
    );
    final membersAsync = ref.watch(tripMemberViewsProvider(widget.tripId));
    final locationsAsync = ref.watch(tripLiveLocationsProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiến độ điểm hẹn'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi quyền nhóm: $error')),
        data: (group) {
          if (!group.isGroupEnabled || !group.viewerIsActiveMember) {
            return const Center(child: Text('Chỉ thành viên nhóm được xem.'));
          }
          return progressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Lỗi tiến độ: $error')),
            data: (progresses) => membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text('Lỗi thành viên: $error')),
              data: (members) => locationsAsync.when(
                loading: () => _progressList(
                  progresses,
                  members,
                  const <TripLiveLocation>[],
                  group.viewerUserId,
                ),
                error: (error, stack) => _progressList(
                  progresses,
                  members,
                  const <TripLiveLocation>[],
                  group.viewerUserId,
                ),
                data: (locations) => _progressList(
                  progresses,
                  members,
                  locations,
                  group.viewerUserId,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
