import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/trip_track_local_repository.dart';
import '../../domain/trip_track_point.dart';

/// Optional foreground-only GPS recording and local route replay.
/// Not background tracking, not navigation, and not synced across devices.
class TripTrackPage extends StatefulWidget {
  const TripTrackPage({required this.tripId, super.key});

  final String tripId;

  @override
  State<TripTrackPage> createState() => _TripTrackPageState();
}

class _TripTrackPageState extends State<TripTrackPage>
    with WidgetsBindingObserver {
  final _repository = TripTrackLocalRepository();
  final _map = MapController();
  final _points = <TripTrackPoint>[];
  StreamSubscription<Position>? _subscription;
  Timer? _replayTimer;
  Future<void> _savePipeline = Future<void>.value();
  String? _userId;
  String? _error;
  bool _loading = true;
  bool _recording = false;
  int _playIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        throw StateError('Cần đăng nhập.');
      }
      final loaded = await _repository.load(widget.tripId, uid);
      if (!mounted) {
        return;
      }
      setState(() {
        _userId = uid;
        _points.addAll(loaded);
        _playIndex = _points.isEmpty ? 0 : _points.length - 1;
        _loading = false;
      });
      if (loaded.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _map.move(LatLng(loaded.last.latitude, loaded.last.longitude), 14);
          }
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _start() async {
    _stopReplay();
    if (!await Geolocator.isLocationServiceEnabled()) {
      _show('Hãy bật GPS của thiết bị.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      _show('Chưa được cấp quyền vị trí.');
      return;
    }
    setState(() => _recording = true);
    _subscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          _onGps,
          onError: (Object error) {
            _show('GPS gặp lỗi: $error');
            _stop();
          },
        );
  }

  void _onGps(Position position) {
    if (!_recording || !mounted || _userId == null) {
      return;
    }
    if (!position.accuracy.isFinite || position.accuracy > 70) {
      return;
    }
    final point = TripTrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      measuredAt: position.timestamp.toUtc(),
    );
    if (!point.isValid) {
      return;
    }
    if (_points.isNotEmpty) {
      final last = _points.last;
      final seconds = point.measuredAt.difference(last.measuredAt).inSeconds;
      if (seconds <= 0 || (seconds < 20 && last.metersTo(point) < 10)) {
        return;
      }
    }
    if (_points.length >= 3000) {
      _show('Đã đạt giới hạn 3.000 điểm. Hãy lưu phiên ghi hiện tại.');
      _stop();
      return;
    }
    setState(() {
      _points.add(point);
      _playIndex = _points.length - 1;
    });
    final snapshot = List<TripTrackPoint>.of(_points);
    final userId = _userId!;
    _savePipeline = _savePipeline
        .then((_) => _repository.save(widget.tripId, userId, snapshot))
        .catchError((Object error) {
          if (mounted) {
            _show('Không lưu được track: $error');
          }
        });
  }

  Future<void> _stop() async {
    if (!_recording && _subscription == null) {
      return;
    }
    setState(() => _recording = false);
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    await _savePipeline;
  }

  void _stopReplay() {
    _replayTimer?.cancel();
    _replayTimer = null;
  }

  void _startReplay() {
    if (_recording || _points.length < 2) {
      return;
    }
    _stopReplay();
    setState(() => _playIndex = 0);
    _replayTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted || _playIndex >= _points.length - 1) {
        _stopReplay();
        return;
      }
      setState(() => _playIndex += 1);
      _map.move(
        LatLng(_points[_playIndex].latitude, _points[_playIndex].longitude),
        14,
      );
    });
  }

  Future<void> _clear() async {
    await _stop();
    if (!mounted) {
      return;
    }
    _stopReplay();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Xóa dữ liệu hành trình?'),
        content: const Text('Hành trình lưu trên thiết bị sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || _userId == null) {
      return;
    }
    await _repository.remove(widget.tripId, _userId!);
    if (mounted) {
      setState(() {
        _points.clear();
        _playIndex = 0;
      });
    }
  }

  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recording = false;
    _subscription?.cancel();
    _stopReplay();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _points.isEmpty
        ? null
        : _points[_playIndex.clamp(0, _points.length - 1).toInt()];
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi / xem lại hành trình')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: selected == null
                          ? const LatLng(16.047079, 108.206230)
                          : LatLng(selected.latitude, selected.longitude),
                      initialZoom: selected == null ? 5 : 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.anhleduc333.phuotthu',
                      ),
                      if (_points.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _points
                                  .map((p) => LatLng(p.latitude, p.longitude))
                                  .toList(growable: false),
                              strokeWidth: 4,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      if (selected != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                selected.latitude,
                                selected.longitude,
                              ),
                              height: 50,
                              width: 50,
                              child: const Icon(
                                Icons.location_on,
                                size: 42,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${_points.length} điểm GPS • '
                        '${_recording ? 'Đang ghi' : 'Không ghi'}',
                      ),
                      if (_points.length > 1)
                        Slider(
                          min: 0,
                          max: (_points.length - 1).toDouble(),
                          divisions: _points.length - 1,
                          value: _playIndex.toDouble(),
                          onChanged: _recording
                              ? null
                              : (v) {
                                  _stopReplay();
                                  setState(() => _playIndex = v.round());
                                  final p = _points[_playIndex];
                                  _map.move(
                                    LatLng(p.latitude, p.longitude),
                                    14,
                                  );
                                },
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _recording ? _stop : _start,
                            icon: Icon(
                              _recording
                                  ? Icons.stop
                                  : Icons.fiber_manual_record,
                            ),
                            label: Text(
                              _recording ? 'Dừng ghi' : 'Bắt đầu ghi',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _recording || _points.length < 2
                                ? null
                                : _startReplay,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Phát lại'),
                          ),
                          TextButton.icon(
                            onPressed: _points.isEmpty ? null : _clear,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Xóa track'),
                          ),
                        ],
                      ),
                      const Text(
                        'Bản thử nghiệm: chỉ ghi khi màn hình đang mở. '
                        'Track lưu trên thiết bị, không đồng bộ đám mây; '
                        'bản đồ nền vẫn cần Internet.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
