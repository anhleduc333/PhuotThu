import '../../vehicle/domain/vehicle.dart';
import 'trip_readiness.dart';

enum VehicleReadinessProfileIssueType {
  noVehicle,
  missingFuelType,
  missingFuelTankCapacity,
  missingFuelConsumption,
  missingBatteryCapacity,
}

extension VehicleReadinessProfileIssueTypeX
    on VehicleReadinessProfileIssueType {
  String get key {
    switch (this) {
      case VehicleReadinessProfileIssueType.noVehicle:
        return 'no_vehicle';
      case VehicleReadinessProfileIssueType.missingFuelType:
        return 'missing_fuel_type';
      case VehicleReadinessProfileIssueType.missingFuelTankCapacity:
        return 'missing_fuel_tank_capacity';
      case VehicleReadinessProfileIssueType.missingFuelConsumption:
        return 'missing_fuel_consumption';
      case VehicleReadinessProfileIssueType.missingBatteryCapacity:
        return 'missing_battery_capacity';
    }
  }

  String get label {
    switch (this) {
      case VehicleReadinessProfileIssueType.noVehicle:
        return 'Chưa chọn phương tiện';
      case VehicleReadinessProfileIssueType.missingFuelType:
        return 'Chưa khai báo loại nhiên liệu';
      case VehicleReadinessProfileIssueType.missingFuelTankCapacity:
        return 'Chưa khai báo dung tích bình nhiên liệu';
      case VehicleReadinessProfileIssueType.missingFuelConsumption:
        return 'Chưa khai báo mức tiêu hao nhiên liệu';
      case VehicleReadinessProfileIssueType.missingBatteryCapacity:
        return 'Chưa khai báo dung lượng pin';
    }
  }
}

class VehicleReadinessProfileIssue {
  const VehicleReadinessProfileIssue({
    required this.type,
    required this.message,
  });

  final VehicleReadinessProfileIssueType type;
  final String message;
}

class VehicleReadinessConfirmations {
  const VehicleReadinessConfirmations({
    this.fuelOrEnergyReady,
    this.mechanicalConditionOk,
    this.tiresOk,
    this.documentsAvailable,
    this.checkedAt,
  });

  /// null = chưa kiểm tra, true = đã sẵn sàng, false = cần xử lý.
  final bool? fuelOrEnergyReady;

  /// Người dùng xác nhận tình trạng vận hành cơ bản trước chuyến đi.
  final bool? mechanicalConditionOk;

  /// Người dùng xác nhận lốp ở trạng thái phù hợp để khởi hành.
  final bool? tiresOk;

  /// Người dùng xác nhận đã có giấy tờ phương tiện cần thiết.
  final bool? documentsAvailable;

  final DateTime? checkedAt;

  bool get isComplete =>
      fuelOrEnergyReady != null &&
      mechanicalConditionOk != null &&
      tiresOk != null &&
      documentsAvailable != null;
}

class VehicleReadinessEvaluation {
  const VehicleReadinessEvaluation({
    required this.items,
    required this.profileIssues,
    required this.hasVehicle,
  });

  final List<TripReadinessItem> items;
  final List<VehicleReadinessProfileIssue> profileIssues;
  final bool hasVehicle;

  bool get hasProfileIssues => profileIssues.isNotEmpty;

  List<TripReadinessItem> get actionItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.requiresAction),
      );

  List<TripReadinessItem> get uncheckedItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.status == TripReadinessItemStatus.unknown),
      );

  List<TripReadinessItem> get blockingItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.blocksReadiness),
      );

  int get readyCount => items.where((item) => item.isReady).length;

  bool get allRequiredReady =>
      items.where((item) => item.isRequired).every((item) => item.isReady);
}

class VehicleReadinessEvaluator {
  const VehicleReadinessEvaluator();

  VehicleReadinessEvaluation evaluate({
    required Vehicle? vehicle,
    VehicleReadinessConfirmations confirmations =
        const VehicleReadinessConfirmations(),
  }) {
    if (vehicle == null) {
      return VehicleReadinessEvaluation(
        hasVehicle: false,
        profileIssues: const [
          VehicleReadinessProfileIssue(
            type: VehicleReadinessProfileIssueType.noVehicle,
            message:
                'Chuyến đi chưa chọn phương tiện nên chưa thể hoàn tất '
                'kiểm tra sẵn sàng phương tiện.',
          ),
        ],
        items: List<TripReadinessItem>.unmodifiable(_missingVehicleItems()),
      );
    }

    final profileIssues = _profileIssues(vehicle);
    final checkedAt = confirmations.checkedAt?.toUtc();

    final items = <TripReadinessItem>[
      TripReadinessItem(
        type: TripReadinessItemType.vehicleFuelOrEnergy,
        status: _confirmationStatus(confirmations.fuelOrEnergyReady),
        isRequired: true,
        source: TripReadinessSourceType.manual,
        description: _fuelOrEnergyDescription(vehicle, profileIssues),
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleMechanicalCondition,
        status: _confirmationStatus(confirmations.mechanicalConditionOk),
        isRequired: true,
        source: TripReadinessSourceType.manual,
        description:
            'Xác nhận xe không có dấu hiệu bất thường ảnh hưởng đến việc '
            'khởi hành. Đây là checklist người dùng, không thay thế kiểm tra '
            'kỹ thuật chuyên môn.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleTires,
        status: _confirmationStatus(confirmations.tiresOk),
        isRequired: true,
        source: TripReadinessSourceType.manual,
        description:
            'Xác nhận tình trạng lốp phù hợp trước khi đi. PhuotThu hiện '
            'không đọc cảm biến áp suất hoặc độ mòn lốp.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleDocuments,
        status: _documentsStatus(confirmations.documentsAvailable),
        isRequired: true,
        source: TripReadinessSourceType.manual,
        description:
            'Xác nhận đã chuẩn bị giấy tờ phương tiện cần thiết cho chuyến đi.',
        lastCheckedAt: checkedAt,
      ),
    ];

    return VehicleReadinessEvaluation(
      hasVehicle: true,
      items: List<TripReadinessItem>.unmodifiable(items),
      profileIssues: List<VehicleReadinessProfileIssue>.unmodifiable(
        profileIssues,
      ),
    );
  }

  List<TripReadinessItem> _missingVehicleItems() {
    const description = 'Chưa chọn phương tiện cho chuyến đi.';

    return const [
      TripReadinessItem(
        type: TripReadinessItemType.vehicleFuelOrEnergy,
        status: TripReadinessItemStatus.missing,
        isRequired: true,
        source: TripReadinessSourceType.vehicleProfile,
        description: description,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleMechanicalCondition,
        status: TripReadinessItemStatus.missing,
        isRequired: true,
        source: TripReadinessSourceType.vehicleProfile,
        description: description,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleTires,
        status: TripReadinessItemStatus.missing,
        isRequired: true,
        source: TripReadinessSourceType.vehicleProfile,
        description: description,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.vehicleDocuments,
        status: TripReadinessItemStatus.missing,
        isRequired: true,
        source: TripReadinessSourceType.vehicleProfile,
        description: description,
      ),
    ];
  }

  List<VehicleReadinessProfileIssue> _profileIssues(Vehicle vehicle) {
    final issues = <VehicleReadinessProfileIssue>[];
    final fuelType = vehicle.fuelType?.trim().toLowerCase();

    if (fuelType == null || fuelType.isEmpty) {
      issues.add(
        const VehicleReadinessProfileIssue(
          type: VehicleReadinessProfileIssueType.missingFuelType,
          message:
              'Hồ sơ xe chưa có loại nhiên liệu/năng lượng nên một số '
              'ước tính hành trình có thể chưa đầy đủ.',
        ),
      );

      return issues;
    }

    if (fuelType == 'electric') {
      final batteryCapacity = vehicle.batteryCapacityKwh;

      if (batteryCapacity == null ||
          !batteryCapacity.isFinite ||
          batteryCapacity <= 0) {
        issues.add(
          const VehicleReadinessProfileIssue(
            type: VehicleReadinessProfileIssueType.missingBatteryCapacity,
            message: 'Xe điện chưa có dung lượng pin hợp lệ trong hồ sơ.',
          ),
        );
      }

      return issues;
    }

    final tankCapacity = vehicle.fuelTankCapacityL;

    if (tankCapacity == null || !tankCapacity.isFinite || tankCapacity <= 0) {
      issues.add(
        const VehicleReadinessProfileIssue(
          type: VehicleReadinessProfileIssueType.missingFuelTankCapacity,
          message: 'Xe chưa có dung tích bình nhiên liệu hợp lệ trong hồ sơ.',
        ),
      );
    }

    final consumption = vehicle.consumptionLPer100Km;

    if (consumption == null || !consumption.isFinite || consumption <= 0) {
      issues.add(
        const VehicleReadinessProfileIssue(
          type: VehicleReadinessProfileIssueType.missingFuelConsumption,
          message: 'Xe chưa có mức tiêu hao nhiên liệu hợp lệ trong hồ sơ.',
        ),
      );
    }

    return issues;
  }

  TripReadinessItemStatus _confirmationStatus(bool? value) {
    if (value == null) {
      return TripReadinessItemStatus.unknown;
    }

    return value
        ? TripReadinessItemStatus.ready
        : TripReadinessItemStatus.needsAttention;
  }

  TripReadinessItemStatus _documentsStatus(bool? value) {
    if (value == null) {
      return TripReadinessItemStatus.unknown;
    }

    return value
        ? TripReadinessItemStatus.ready
        : TripReadinessItemStatus.missing;
  }

  String _fuelOrEnergyDescription(
    Vehicle vehicle,
    List<VehicleReadinessProfileIssue> issues,
  ) {
    final fuelType = vehicle.fuelType?.trim().toLowerCase();
    final profileIssueText = issues
        .where(
          (issue) => issue.type != VehicleReadinessProfileIssueType.noVehicle,
        )
        .map((issue) => issue.message)
        .join(' ');

    final base = fuelType == 'electric'
        ? 'Xác nhận mức pin hiện tại đủ cho kế hoạch khởi hành hoặc đã có '
              'kế hoạch sạc phù hợp.'
        : 'Xác nhận lượng nhiên liệu hiện tại đủ để khởi hành hoặc đã có '
              'kế hoạch tiếp nhiên liệu phù hợp.';

    if (profileIssueText.isEmpty) {
      return '$base PhuotThu không tự suy ra mức nhiên liệu/pin thực tế từ '
          'thông số hồ sơ xe.';
    }

    return '$base $profileIssueText';
  }
}
