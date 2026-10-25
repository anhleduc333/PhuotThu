import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/trip_live_location_providers.dart';
import '../data/trip_live_map_providers.dart';
import '../domain/trip_convoy_safety.dart';
import '../domain/trip_live_map_entry.dart';
import '../domain/trip_member.dart';

class TripGroupLiveMapPage extends ConsumerStatefulWidget {
  const TripGroupLiveMapPage({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripGroupLiveMapPage> createState() =>
      _TripGroupLiveMapPageState();
}

class _TripGroupLiveMapPageState extends ConsumerState<TripGroupLiveMapPage> {
  static const LatLng _defaultCenter = LatLng(16.047079, 108.206230);

  final MapController _mapController = MapController();

  final TripLiveMapEntryAssembler _assembler =
      const TripLiveMapEntryAssembler();

  final TripConvoySafetyAnalyzer _convoyAnalyzer =
      const TripConvoySafetyAnalyzer();

  Timer? _freshnessTimer;
  bool _didInitialFit = false;

  @override
  void initState() {
    super.initState();

    _freshnessTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fitEntries(List<TripLiveMapEntry> entries) {
    if (entries.isEmpty) {
      return;
    }

    final points = entries
        .map(
          (entry) => LatLng(entry.location.latitude, entry.location.longitude),
        )
        .toList(growable: false);

    if (points.length == 1) {
      _mapController.move(points.single, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 80, 48, 220),
        maxZoom: 16,
      ),
    );
  }

  void _scheduleInitialFit(List<TripLiveMapEntry> entries) {
    if (_didInitialFit || entries.isEmpty) {
      return;
    }

    _didInitialFit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitEntries(entries);
      }
    });
  }

  void _focusEntry(TripLiveMapEntry entry) {
    _mapController.move(
      LatLng(entry.location.latitude, entry.location.longitude),
      16,
    );
  }

  String _formatAge(Duration age) {
    if (age.inSeconds < 10) {
      return 'vừa cập nhật';
    }

    if (age.inMinutes < 1) {
      return '${age.inSeconds} giây trước';
    }

    if (age.inHours < 1) {
      return '${age.inMinutes} phút trước';
    }

    return '${age.inHours} giờ trước';
  }

  String _formatRecordedAt(DateTime value) {
    final local = value.toLocal();

    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  TripConvoyMemberFinding? _findingForEntry(
    TripConvoySafetySummary summary,
    TripLiveMapEntry entry,
  ) {
    for (final finding in summary.findings) {
      if (finding.entry.userId == entry.userId) {
        return finding;
      }
    }

    return null;
  }

  Color _safetyColor(BuildContext context, TripConvoySafetyLevel level) {
    switch (level) {
      case TripConvoySafetyLevel.noData:
        return Theme.of(context).colorScheme.outline;
      case TripConvoySafetyLevel.normal:
        return Theme.of(context).colorScheme.primary;
      case TripConvoySafetyLevel.caution:
        return Colors.orange.shade700;
      case TripConvoySafetyLevel.critical:
        return Theme.of(context).colorScheme.error;
    }
  }

  IconData _safetyIcon(TripConvoySafetyLevel level) {
    switch (level) {
      case TripConvoySafetyLevel.noData:
        return Icons.help_outline;
      case TripConvoySafetyLevel.normal:
        return Icons.shield_outlined;
      case TripConvoySafetyLevel.caution:
        return Icons.warning_amber_rounded;
      case TripConvoySafetyLevel.critical:
        return Icons.report_problem_outlined;
    }
  }

  String _formatDistanceMeters(double? meters) {
    if (meters == null) {
      return 'Chưa xác định';
    }

    if (meters < 1000) {
      return '${meters.round()} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _safetySummaryText(TripConvoySafetySummary summary) {
    if (summary.sharingCount == 0) {
      return 'Chưa có thành viên chia sẻ vị trí.';
    }

    if (!summary.canAssessSeparation) {
      if (summary.staleCount > 0) {
        return '${summary.freshCount} GPS mới • '
            '${summary.staleCount} GPS cũ/mất tín hiệu.';
      }

      return 'Chưa đủ ít nhất 2 vị trí mới để đánh giá khoảng cách đoàn.';
    }

    final maxDistance = _formatDistanceMeters(
      summary.maxFreshPairDistanceMeters,
    );

    if (summary.criticalCount > 0) {
      return '${summary.criticalCount} cảnh báo nghiêm trọng • '
          'độ giãn đoàn tối đa $maxDistance.';
    }

    if (summary.cautionCount > 0) {
      return '${summary.cautionCount} thành viên cần chú ý • '
          'độ giãn đoàn tối đa $maxDistance.';
    }

    return '${summary.freshCount} GPS mới • '
        'độ giãn đoàn tối đa $maxDistance.';
  }

  Widget _buildSafetyBanner(
    BuildContext context,
    TripConvoySafetySummary summary,
  ) {
    final color = _safetyColor(context, summary.level);

    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(_safetyIcon(summary.level), color: color),
        title: Text(
          summary.level.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_safetySummaryText(summary)),
        trailing: summary.hasIssues
            ? Badge(
                label: Text('${summary.cautionCount + summary.criticalCount}'),
                child: const Icon(Icons.notifications_active_outlined),
              )
            : null,
      ),
    );
  }

  Widget _buildMarker(
    BuildContext context,
    TripLiveMapEntry entry,
    DateTime now,
    TripConvoyMemberFinding? finding,
  ) {
    final level = finding?.level ?? TripConvoySafetyLevel.noData;
    final color = _safetyColor(context, level);

    return GestureDetector(
      onTap: () {
        _showEntrySheet(context, entry, now, finding);
      },
      child: SizedBox(
        width: 112,
        height: 72,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 5,
                    offset: Offset(0, 2),
                    color: Colors.black26,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                entry.initials,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              top: 42,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 110),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color),
                ),
                child: Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEntrySheet(
    BuildContext context,
    TripLiveMapEntry entry,
    DateTime now,
    TripConvoyMemberFinding? finding,
  ) async {
    final fresh = entry.isFreshAt(now);
    final age = entry.ageAt(now);
    final safetyLevel = finding?.level ?? TripConvoySafetyLevel.noData;
    final nearestDistanceMeters = finding?.nearestDistanceMeters;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(child: Text(entry.initials)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.displayName,
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                          Text(entry.role.label),
                        ],
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        fresh ? Icons.radio_button_checked : Icons.history,
                        size: 16,
                      ),
                      label: Text(fresh ? 'Trực tiếp' : 'Vị trí cũ'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      _safetyIcon(safetyLevel),
                      size: 18,
                      color: _safetyColor(sheetContext, safetyLevel),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        finding?.state.label ?? 'Chưa có đánh giá an toàn',
                        style: TextStyle(
                          color: _safetyColor(sheetContext, safetyLevel),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (nearestDistanceMeters != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Khoảng cách tới thành viên gần nhất: '
                    '${_formatDistanceMeters(nearestDistanceMeters)}',
                  ),
                ],
                const SizedBox(height: 12),
                Text('Cập nhật: ${_formatAge(age)}'),
                const SizedBox(height: 4),
                Text(_formatRecordedAt(entry.location.recordedAt)),
                const SizedBox(height: 8),
                Text(
                  'Tọa độ: '
                  '${entry.location.latitude.toStringAsFixed(6)}, '
                  '${entry.location.longitude.toStringAsFixed(6)}',
                ),
                if (entry.location.accuracyMeters != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Độ chính xác: '
                    '${entry.location.accuracyMeters!.toStringAsFixed(0)} m',
                  ),
                ],
                if (entry.location.speedMetersPerSecond != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tốc độ GPS: '
                    '${(entry.location.speedMetersPerSecond! * 3.6).toStringAsFixed(1)} km/h',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyOverlay(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Chưa có vị trí trực tiếp',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Khi thành viên bật '
                '"Chia sẻ vị trí của tôi", '
                'marker sẽ xuất hiện tự động '
                'trên bản đồ này.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(
    BuildContext context,
    List<TripLiveMapEntry> entries,
    DateTime now,
    TripConvoySafetySummary safetySummary,
  ) {
    final freshCount = safetySummary.freshCount;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 270),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Vị trí thành viên'),
              subtitle: Text(
                '${entries.length} đang chia sẻ • '
                '$freshCount đang trực tiếp',
              ),
              trailing: IconButton(
                onPressed: entries.isEmpty
                    ? null
                    : () {
                        _fitEntries(entries);
                      },
                tooltip: 'Hiển thị toàn đoàn',
                icon: const Icon(Icons.center_focus_strong),
              ),
            ),
            if (entries.isNotEmpty) const Divider(height: 1),
            if (entries.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final fresh = entry.isFreshAt(now);
                    final finding = _findingForEntry(safetySummary, entry);
                    final safetyLevel =
                        finding?.level ?? TripConvoySafetyLevel.noData;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 17,
                        child: Text(entry.initials),
                      ),
                      title: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.role.label} • '
                        '${finding?.state.label ?? (fresh ? 'Trực tiếp' : 'Vị trí cũ')} • '
                        '${_formatAge(entry.ageAt(now))}',
                      ),
                      trailing: Icon(
                        _safetyIcon(safetyLevel),
                        size: 18,
                        color: _safetyColor(context, safetyLevel),
                      ),
                      onTap: () {
                        _focusEntry(entry);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<TripLiveMapEntry> entries) {
    final now = DateTime.now();
    final safetySummary = _convoyAnalyzer.analyze(entries: entries, now: now);

    _scheduleInitialFit(entries);

    final markers = entries
        .map(
          (entry) => Marker(
            point: LatLng(entry.location.latitude, entry.location.longitude),
            width: 112,
            height: 72,
            child: _buildMarker(
              context,
              entry,
              now,
              _findingForEntry(safetySummary, entry),
            ),
          ),
        )
        .toList(growable: false);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: 5,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.anhleduc333.phuotthu',
            ),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: _buildSafetyBanner(context, safetySummary),
        ),
        if (entries.isEmpty) _buildEmptyOverlay(context),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(context, entries, now, safetySummary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(tripLiveMapMembersProvider(widget.tripId));

    final locationsAsync = ref.watch(tripLiveLocationsProvider(widget.tripId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản đồ nhóm trực tiếp'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(tripLiveMapMembersProvider(widget.tripId));
              ref.invalidate(tripLiveLocationsProvider(widget.tripId));
            },
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return _MapLoadError(
            message: 'Không thể tải thành viên chuyến đi.',
            onRetry: () {
              ref.invalidate(tripLiveMapMembersProvider(widget.tripId));
            },
          );
        },
        data: (members) {
          return locationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              return _MapLoadError(
                message: 'Không thể kết nối Live Location.',
                onRetry: () {
                  ref.invalidate(tripLiveLocationsProvider(widget.tripId));
                },
              );
            },
            data: (locations) {
              final entries = _assembler.assemble(
                tripId: widget.tripId,
                members: members,
                locations: locations,
              );

              return _buildMap(context, entries);
            },
          );
        },
      ),
    );
  }
}

class _MapLoadError extends StatelessWidget {
  const _MapLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
