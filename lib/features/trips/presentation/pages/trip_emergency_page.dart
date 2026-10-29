import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// An emergency-information helper. Does NOT dispatch an SOS or contact rescuers.
class TripEmergencyPage extends StatefulWidget {
  const TripEmergencyPage({required this.tripName, super.key});

  final String tripName;

  @override
  State<TripEmergencyPage> createState() => _TripEmergencyPageState();
}

class _TripEmergencyPageState extends State<TripEmergencyPage> {
  Position? _position;
  String? _message;
  bool _loading = false;

  Future<void> _getLocation() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Dịch vụ vị trí đang tắt.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw StateError('Chưa cấp quyền vị trí cho ứng dụng.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _position = position);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _buildReport() {
    final p = _position;
    if (p == null) {
      return 'Tôi cần hỗ trợ trong chuyến đi "${widget.tripName}". '
          'Tôi chưa thể xác định tọa độ GPS. Hãy liên hệ trực tiếp với tôi.';
    }
    final latitude = p.latitude.toStringAsFixed(6);
    final longitude = p.longitude.toStringAsFixed(6);
    return 'TÔI CẦN HỖ TRỢ\n'
        'Chuyến đi: ${widget.tripName}\n'
        'Tọa độ GPS: $latitude, $longitude\n'
        'Độ chính xác báo cáo: ${p.accuracy.toStringAsFixed(0)} m\n'
        'Thời điểm GPS: ${p.timestamp.toLocal()}\n'
        'Xem bản đồ: https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=16/$latitude/$longitude\n'
        'Hãy liên lạc xác minh tình trạng của tôi.';
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _buildReport()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép nội dung để tự gửi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin hỗ trợ khẩn cấp')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'CHỨC NĂNG HỖ TRỢ, KHÔNG PHẢI HỆ THỐNG CỨU HỘ. '
                  'Ứng dụng không tự gửi SOS, không gọi cơ quan khẩn cấp '
                  'và không báo động cho thành viên. '
                  'Nếu nguy hiểm, hãy chủ động gọi trợ giúp bằng điện thoại.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _getLocation,
              icon: const Icon(Icons.my_location),
              label: Text(_loading ? 'Đang lấy GPS...' : 'Lấy vị trí hiện tại'),
            ),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            SelectableText(_buildReport()),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy),
              label: const Text('Sao chép nội dung để tự gửi cho người hỗ trợ'),
            ),
          ],
        ),
      ),
    );
  }
}
