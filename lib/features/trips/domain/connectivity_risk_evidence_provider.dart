import 'connectivity_risk.dart';

class ConnectivityRiskSampleLocation {
  const ConnectivityRiskSampleLocation({
    required this.latitude,
    required this.longitude,
    required this.distanceFromStartMeters,
    required this.progressRatio,
  }) : assert(latitude >= -90 && latitude <= 90),
       assert(longitude >= -180 && longitude <= 180),
       assert(distanceFromStartMeters >= 0),
       assert(progressRatio >= 0 && progressRatio <= 1);

  final double latitude;
  final double longitude;

  /// Khoảng cách tính từ đầu tuyến.
  final double distanceFromStartMeters;

  /// Tiến độ trên tuyến từ 0.0 đến 1.0.
  final double progressRatio;

  double get distanceFromStartKm => distanceFromStartMeters / 1000;

  double get progressPercent => progressRatio * 100;
}

abstract interface class ConnectivityRiskEvidenceProvider {
  /// ID ngắn gọn của provider, dùng để trace nguồn dữ liệu.
  String get providerId;

  /// Thu thập các evidence cho một sample dọc tuyến.
  ///
  /// Provider có thể trả danh sách rỗng khi không có dữ liệu.
  Future<List<ConnectivityRiskEvidence>> getEvidence(
    ConnectivityRiskSampleLocation location,
  );
}
