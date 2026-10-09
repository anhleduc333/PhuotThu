import '../../vehicle/domain/vehicle.dart';

class TripFuelEstimate {
  const TripFuelEstimate({required this.liters, this.tankEquivalent});

  final double liters;

  /// Số bình nhiên liệu tương đương cần cho toàn tuyến.
  ///
  /// Ví dụ:
  /// 1.5 = lượng nhiên liệu tương đương 1,5 bình.
  final double? tankEquivalent;
}

class TripFuelEstimator {
  const TripFuelEstimator();

  TripFuelEstimate? calculate({
    required int distanceMeters,
    required Vehicle vehicle,
  }) {
    if (distanceMeters <= 0) {
      return null;
    }

    // Xe điện không dùng đơn vị lít/100 km.
    //
    // batteryCapacityKwh chỉ là dung lượng pin,
    // chưa đủ để tính tiêu thụ điện.
    if (vehicle.fuelType == 'electric') {
      return null;
    }

    final consumption = vehicle.consumptionLPer100Km;

    if (consumption == null || consumption <= 0) {
      return null;
    }

    final distanceKm = distanceMeters / 1000;

    final liters = distanceKm * consumption / 100;

    final tankCapacity = vehicle.fuelTankCapacityL;

    double? tankEquivalent;

    if (tankCapacity != null && tankCapacity > 0) {
      tankEquivalent = liters / tankCapacity;
    }

    return TripFuelEstimate(liters: liters, tankEquivalent: tankEquivalent);
  }
}
