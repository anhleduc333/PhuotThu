enum OfflineReadinessLevel { unknown, notReady, needsAttention, ready }

extension OfflineReadinessLevelX on OfflineReadinessLevel {
  String get key {
    switch (this) {
      case OfflineReadinessLevel.unknown:
        return 'unknown';
      case OfflineReadinessLevel.notReady:
        return 'not_ready';
      case OfflineReadinessLevel.needsAttention:
        return 'needs_attention';
      case OfflineReadinessLevel.ready:
        return 'ready';
    }
  }

  String get label {
    switch (this) {
      case OfflineReadinessLevel.unknown:
        return 'Chưa đánh giá';
      case OfflineReadinessLevel.notReady:
        return 'Chưa sẵn sàng';
      case OfflineReadinessLevel.needsAttention:
        return 'Cần chuẩn bị thêm';
      case OfflineReadinessLevel.ready:
        return 'Sẵn sàng';
    }
  }

  bool get isReady => this == OfflineReadinessLevel.ready;

  bool get requiresAction =>
      this == OfflineReadinessLevel.notReady ||
      this == OfflineReadinessLevel.needsAttention;
}

enum OfflineReadinessItemType {
  tripDetails,
  routeGeometry,
  routeSummary,
  essentialPois,
  emergencyInfo,
  connectivityRiskAnalysis,
  offlineMap,
}

extension OfflineReadinessItemTypeX on OfflineReadinessItemType {
  String get key {
    switch (this) {
      case OfflineReadinessItemType.tripDetails:
        return 'trip_details';
      case OfflineReadinessItemType.routeGeometry:
        return 'route_geometry';
      case OfflineReadinessItemType.routeSummary:
        return 'route_summary';
      case OfflineReadinessItemType.essentialPois:
        return 'essential_pois';
      case OfflineReadinessItemType.emergencyInfo:
        return 'emergency_info';
      case OfflineReadinessItemType.connectivityRiskAnalysis:
        return 'connectivity_risk_analysis';
      case OfflineReadinessItemType.offlineMap:
        return 'offline_map';
    }
  }

  String get label {
    switch (this) {
      case OfflineReadinessItemType.tripDetails:
        return 'Thông tin chuyến đi';
      case OfflineReadinessItemType.routeGeometry:
        return 'Dữ liệu tuyến đường';
      case OfflineReadinessItemType.routeSummary:
        return 'Tóm tắt hành trình';
      case OfflineReadinessItemType.essentialPois:
        return 'Điểm thiết yếu dọc tuyến';
      case OfflineReadinessItemType.emergencyInfo:
        return 'Thông tin khẩn cấp';
      case OfflineReadinessItemType.connectivityRiskAnalysis:
        return 'Phân tích nguy cơ kết nối';
      case OfflineReadinessItemType.offlineMap:
        return 'Bản đồ offline';
    }
  }
}

enum OfflineReadinessItemStatus { missing, stale, ready, notApplicable }

extension OfflineReadinessItemStatusX on OfflineReadinessItemStatus {
  String get key {
    switch (this) {
      case OfflineReadinessItemStatus.missing:
        return 'missing';
      case OfflineReadinessItemStatus.stale:
        return 'stale';
      case OfflineReadinessItemStatus.ready:
        return 'ready';
      case OfflineReadinessItemStatus.notApplicable:
        return 'not_applicable';
    }
  }

  String get label {
    switch (this) {
      case OfflineReadinessItemStatus.missing:
        return 'Thiếu dữ liệu';
      case OfflineReadinessItemStatus.stale:
        return 'Cần cập nhật';
      case OfflineReadinessItemStatus.ready:
        return 'Sẵn sàng';
      case OfflineReadinessItemStatus.notApplicable:
        return 'Không áp dụng';
    }
  }

  bool get isUsable =>
      this == OfflineReadinessItemStatus.ready ||
      this == OfflineReadinessItemStatus.notApplicable;
}

class OfflineReadinessItem {
  const OfflineReadinessItem({
    required this.type,
    required this.status,
    required this.isRequired,
    this.title,
    this.description,
    this.lastUpdatedAt,
    this.estimatedSizeBytes,
  }) : assert(estimatedSizeBytes == null || estimatedSizeBytes >= 0);

  final OfflineReadinessItemType type;
  final OfflineReadinessItemStatus status;

  /// true nếu thiếu hạng mục này sẽ ảnh hưởng trực tiếp đến mức sẵn sàng.
  final bool isRequired;

  /// Cho phép UI ghi đè nhãn mặc định nếu cần.
  final String? title;

  final String? description;

  final DateTime? lastUpdatedAt;

  /// Dung lượng ước tính của dữ liệu offline liên quan đến hạng mục này.
  final int? estimatedSizeBytes;

  String get displayTitle =>
      title?.trim().isNotEmpty == true ? title!.trim() : type.label;

  bool get isReady => status == OfflineReadinessItemStatus.ready;

  bool get requiresAction =>
      status == OfflineReadinessItemStatus.missing ||
      status == OfflineReadinessItemStatus.stale;

  bool get blocksReadiness =>
      isRequired &&
      status != OfflineReadinessItemStatus.ready &&
      status != OfflineReadinessItemStatus.notApplicable;

  double? get estimatedSizeMb {
    final bytes = estimatedSizeBytes;

    if (bytes == null) {
      return null;
    }

    return bytes / (1024 * 1024);
  }
}

class OfflineReadinessAssessment {
  const OfflineReadinessAssessment({
    required this.level,
    required this.score,
    required this.items,
    this.assessedAt,
    this.connectivityWarningRoutePercent,
    this.recommendedBeforeDeparture = true,
  }) : assert(score >= 0 && score <= 1),
       assert(
         connectivityWarningRoutePercent == null ||
             (connectivityWarningRoutePercent >= 0 &&
                 connectivityWarningRoutePercent <= 100),
       );

  final OfflineReadinessLevel level;

  /// Điểm chuẩn hóa 0.0–1.0.
  /// DEV-08F.2 sẽ chịu trách nhiệm tính điểm này.
  final double score;

  final List<OfflineReadinessItem> items;

  final DateTime? assessedAt;

  /// Tỷ lệ route HIGH/CRITICAL lấy từ ConnectivityRiskAssessment.
  /// null nghĩa là chưa có dữ liệu connectivity risk.
  final double? connectivityWarningRoutePercent;

  /// Cho phép policy sau này chỉ ra rằng người dùng nên hoàn tất
  /// chuẩn bị offline trước khi khởi hành.
  final bool recommendedBeforeDeparture;

  double get scorePercent => score * 100;

  bool get isReady => level.isReady;

  bool get requiresAction => level.requiresAction;

  bool get hasConnectivityRiskContext =>
      connectivityWarningRoutePercent != null;

  List<OfflineReadinessItem> get requiredItems =>
      List<OfflineReadinessItem>.unmodifiable(
        items.where((item) => item.isRequired),
      );

  List<OfflineReadinessItem> get missingRequiredItems =>
      List<OfflineReadinessItem>.unmodifiable(
        items.where(
          (item) =>
              item.isRequired &&
              item.status == OfflineReadinessItemStatus.missing,
        ),
      );

  List<OfflineReadinessItem> get staleRequiredItems =>
      List<OfflineReadinessItem>.unmodifiable(
        items.where(
          (item) =>
              item.isRequired &&
              item.status == OfflineReadinessItemStatus.stale,
        ),
      );

  List<OfflineReadinessItem> get actionItems =>
      List<OfflineReadinessItem>.unmodifiable(
        items.where((item) => item.requiresAction),
      );

  bool get hasBlockingItems => items.any((item) => item.blocksReadiness);

  int get readyItemCount => items.where((item) => item.isReady).length;

  int get requiredItemCount => items.where((item) => item.isRequired).length;

  int get readyRequiredItemCount =>
      items.where((item) => item.isRequired && item.isReady).length;

  double get requiredCompletionRatio {
    final total = requiredItemCount;

    if (total == 0) {
      return 1;
    }

    return readyRequiredItemCount / total;
  }

  double get requiredCompletionPercent => requiredCompletionRatio * 100;

  int get totalEstimatedSizeBytes {
    return items.fold<int>(
      0,
      (sum, item) => sum + (item.estimatedSizeBytes ?? 0),
    );
  }

  double get totalEstimatedSizeMb => totalEstimatedSizeBytes / (1024 * 1024);
}
