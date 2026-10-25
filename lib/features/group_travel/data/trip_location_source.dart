import '../domain/trip_device_location.dart';

enum TripLocationAccessStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

extension TripLocationAccessStatusX on TripLocationAccessStatus {
  bool get canReadLocation => this == TripLocationAccessStatus.ready;

  String get label {
    switch (this) {
      case TripLocationAccessStatus.ready:
        return 'Sẵn sàng';
      case TripLocationAccessStatus.serviceDisabled:
        return 'Dịch vụ vị trí đang tắt';
      case TripLocationAccessStatus.permissionDenied:
        return 'Chưa cấp quyền vị trí';
      case TripLocationAccessStatus.permissionDeniedForever:
        return 'Quyền vị trí bị từ chối vĩnh viễn';
    }
  }
}

class TripLocationAccessResult {
  const TripLocationAccessResult({required this.status});

  final TripLocationAccessStatus status;

  bool get canReadLocation => status.canReadLocation;
}

abstract interface class TripLocationSource {
  Future<TripLocationAccessResult> ensureAccess();

  Stream<TripDeviceLocation> watchLocations();
}
