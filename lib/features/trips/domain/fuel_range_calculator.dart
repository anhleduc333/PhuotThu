class FuelRangeEstimate {
  const FuelRangeEstimate({
    required this.tankCapacityLiters,
    required this.consumptionLitersPer100Km,
    required this.startingFuelRatio,
    required this.reserveRatio,
    required this.startingFuelLiters,
    required this.reserveFuelLiters,
    required this.usableFuelLiters,
    required this.theoreticalRangeKm,
    required this.safeRangeKm,
    required this.reserveRangeKm,
  });

  /// Dung tích toàn bộ bình nhiên liệu.
  final double tankCapacityLiters;

  /// Mức tiêu hao của phương tiện.
  final double consumptionLitersPer100Km;

  /// Tỷ lệ nhiên liệu giả định khi bắt đầu chuyến đi.
  ///
  /// 1.0 = đầy bình.
  /// 0.5 = nửa bình.
  final double startingFuelRatio;

  /// Phần nhiên liệu muốn giữ lại làm dự phòng.
  ///
  /// Mặc định 0.25 = 25% dung tích bình.
  final double reserveRatio;

  /// Lượng nhiên liệu thực tế giả định có khi xuất phát.
  final double startingFuelLiters;

  /// Lượng nhiên liệu được giữ lại làm dự phòng.
  final double reserveFuelLiters;

  /// Lượng nhiên liệu có thể sử dụng trước ngưỡng an toàn.
  final double usableFuelLiters;

  /// Tầm hoạt động lý thuyết với lượng nhiên liệu ban đầu.
  final double theoreticalRangeKm;

  /// Tầm hoạt động an toàn trước khi chạm mức dự phòng.
  final double safeRangeKm;

  /// Quãng đường tương ứng với phần nhiên liệu dự phòng.
  final double reserveRangeKm;

  double get theoreticalRangeMeters => theoreticalRangeKm * 1000;

  double get safeRangeMeters => safeRangeKm * 1000;

  double get reserveRangeMeters => reserveRangeKm * 1000;

  bool canSafelyCoverDistanceMeters(int distanceMeters) {
    if (distanceMeters <= 0) {
      return true;
    }

    return distanceMeters <= safeRangeMeters;
  }

  bool needsFuelStopForDistanceMeters(int distanceMeters) {
    return !canSafelyCoverDistanceMeters(distanceMeters);
  }
}

class FuelRangeCalculator {
  const FuelRangeCalculator();

  FuelRangeEstimate? calculate({
    required double? tankCapacityLiters,
    required double? consumptionLitersPer100Km,
    double startingFuelRatio = 1.0,
    double reserveRatio = 0.25,
  }) {
    if (tankCapacityLiters == null || tankCapacityLiters <= 0) {
      return null;
    }

    if (consumptionLitersPer100Km == null || consumptionLitersPer100Km <= 0) {
      return null;
    }

    if (startingFuelRatio < 0 || startingFuelRatio > 1) {
      return null;
    }

    if (reserveRatio < 0 || reserveRatio >= 1) {
      return null;
    }

    final startingFuelLiters = tankCapacityLiters * startingFuelRatio;

    final reserveFuelLiters = tankCapacityLiters * reserveRatio;

    final usableFuelLiters = (startingFuelLiters - reserveFuelLiters)
        .clamp(0.0, double.infinity)
        .toDouble();

    final theoreticalRangeKm =
        startingFuelLiters / consumptionLitersPer100Km * 100;

    final safeRangeKm = usableFuelLiters / consumptionLitersPer100Km * 100;

    final reserveRangeKm = reserveFuelLiters / consumptionLitersPer100Km * 100;

    return FuelRangeEstimate(
      tankCapacityLiters: tankCapacityLiters,
      consumptionLitersPer100Km: consumptionLitersPer100Km,
      startingFuelRatio: startingFuelRatio,
      reserveRatio: reserveRatio,
      startingFuelLiters: startingFuelLiters,
      reserveFuelLiters: reserveFuelLiters,
      usableFuelLiters: usableFuelLiters,
      theoreticalRangeKm: theoreticalRangeKm,
      safeRangeKm: safeRangeKm,
      reserveRangeKm: reserveRangeKm,
    );
  }
}
