import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A manual map selection. The user—not the app—chooses every checkpoint.
class TripCheckpointMapPickerPage extends StatefulWidget {
  const TripCheckpointMapPickerPage({super.key, this.initialPoint});

  final LatLng? initialPoint;

  @override
  State<TripCheckpointMapPickerPage> createState() =>
      _TripCheckpointMapPickerPageState();
}

class _TripCheckpointMapPickerPageState
    extends State<TripCheckpointMapPickerPage> {
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn điểm hẹn trên bản đồ')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter:
                  widget.initialPoint ?? const LatLng(16.047079, 108.206230),
              initialZoom: widget.initialPoint == null ? 5.0 : 14.0,
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'phuotthu',
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 42,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _selected == null
                      ? 'Chạm vào vị trí muốn dùng làm điểm hẹn.'
                      : 'Đã chọn: '
                            '${_selected!.latitude.toStringAsFixed(6)}, '
                            '${_selected!.longitude.toStringAsFixed(6)}',
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            icon: const Icon(Icons.check),
            label: const Text('Xác nhận vị trí'),
          ),
        ),
      ),
    );
  }
}
