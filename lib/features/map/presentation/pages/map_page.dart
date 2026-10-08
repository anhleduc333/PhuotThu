import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  static const LatLng _initialCenter = LatLng(21.028511, 105.804817);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản đồ')),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 12,
          minZoom: 3,
          maxZoom: 19,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

            // Nếu applicationId hiện tại của anh khác,
            // chỉ cần thay đúng chuỗi này.
            userAgentPackageName: 'com.anhleduc333.phuotthu',
          ),

          const MarkerLayer(
            markers: [
              Marker(
                point: _initialCenter,
                width: 50,
                height: 50,
                child: Icon(Icons.location_on, size: 44),
              ),
            ],
          ),

          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}
