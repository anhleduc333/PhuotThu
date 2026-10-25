import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../data/trip_live_location_providers.dart';
import '../data/trip_live_map_providers.dart';
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

  Widget _buildMarker(
    BuildContext context,
    TripLiveMapEntry entry,
    DateTime now,
  ) {
    final isFresh = entry.isFreshAt(now);
    final color = isFresh
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    return GestureDetector(
      onTap: () {
        _showEntrySheet(context, entry, now);
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
  ) async {
    final fresh = entry.isFreshAt(now);
    final age = entry.ageAt(now);

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
  ) {
    final freshCount = entries.where((entry) => entry.isFreshAt(now)).length;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 210),
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
                        '${fresh ? 'Trực tiếp' : 'Vị trí cũ'} • '
                        '${_formatAge(entry.ageAt(now))}',
                      ),
                      trailing: Icon(
                        fresh ? Icons.radio_button_checked : Icons.history,
                        size: 18,
                        color: fresh
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
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

    _scheduleInitialFit(entries);

    final markers = entries
        .map(
          (entry) => Marker(
            point: LatLng(entry.location.latitude, entry.location.longitude),
            width: 112,
            height: 72,
            child: _buildMarker(context, entry, now),
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
        if (entries.isEmpty) _buildEmptyOverlay(context),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(context, entries, now),
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
