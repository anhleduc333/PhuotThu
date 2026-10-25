enum TripReadinessLevel { unknown, notReady, needsAttention, ready }

extension TripReadinessLevelX on TripReadinessLevel {
  String get key {
    switch (this) {
      case TripReadinessLevel.unknown:
        return 'unknown';
      case TripReadinessLevel.notReady:
        return 'not_ready';
      case TripReadinessLevel.needsAttention:
        return 'needs_attention';
      case TripReadinessLevel.ready:
        return 'ready';
    }
  }

  String get label {
    switch (this) {
      case TripReadinessLevel.unknown:
        return 'Chưa đánh giá';
      case TripReadinessLevel.notReady:
        return 'Chưa sẵn sàng';
      case TripReadinessLevel.needsAttention:
        return 'Cần chuẩn bị thêm';
      case TripReadinessLevel.ready:
        return 'Sẵn sàng';
    }
  }

  int get severity {
    switch (this) {
      case TripReadinessLevel.unknown:
        return -1;
      case TripReadinessLevel.ready:
        return 0;
      case TripReadinessLevel.needsAttention:
        return 1;
      case TripReadinessLevel.notReady:
        return 2;
    }
  }

  bool get isReady => this == TripReadinessLevel.ready;

  bool get requiresAction =>
      this == TripReadinessLevel.notReady ||
      this == TripReadinessLevel.needsAttention;
}

enum TripReadinessCategory { offline, vehicle, personal, route, emergency }

extension TripReadinessCategoryX on TripReadinessCategory {
  String get key {
    switch (this) {
      case TripReadinessCategory.offline:
        return 'offline';
      case TripReadinessCategory.vehicle:
        return 'vehicle';
      case TripReadinessCategory.personal:
        return 'personal';
      case TripReadinessCategory.route:
        return 'route';
      case TripReadinessCategory.emergency:
        return 'emergency';
    }
  }

  String get label {
    switch (this) {
      case TripReadinessCategory.offline:
        return 'Dữ liệu offline';
      case TripReadinessCategory.vehicle:
        return 'Phương tiện';
      case TripReadinessCategory.personal:
        return 'Chuẩn bị cá nhân';
      case TripReadinessCategory.route:
        return 'Tuyến đường';
      case TripReadinessCategory.emergency:
        return 'Khẩn cấp / SOS';
    }
  }
}

enum TripReadinessItemStatus {
  unknown,
  missing,
  needsAttention,
  ready,
  notApplicable,
}

extension TripReadinessItemStatusX on TripReadinessItemStatus {
  String get key {
    switch (this) {
      case TripReadinessItemStatus.unknown:
        return 'unknown';
      case TripReadinessItemStatus.missing:
        return 'missing';
      case TripReadinessItemStatus.needsAttention:
        return 'needs_attention';
      case TripReadinessItemStatus.ready:
        return 'ready';
      case TripReadinessItemStatus.notApplicable:
        return 'not_applicable';
    }
  }

  String get label {
    switch (this) {
      case TripReadinessItemStatus.unknown:
        return 'Chưa kiểm tra';
      case TripReadinessItemStatus.missing:
        return 'Thiếu';
      case TripReadinessItemStatus.needsAttention:
        return 'Cần xử lý';
      case TripReadinessItemStatus.ready:
        return 'Sẵn sàng';
      case TripReadinessItemStatus.notApplicable:
        return 'Không áp dụng';
    }
  }

  bool get isReady => this == TripReadinessItemStatus.ready;

  bool get requiresAction =>
      this == TripReadinessItemStatus.missing ||
      this == TripReadinessItemStatus.needsAttention;

  bool get isResolved =>
      this == TripReadinessItemStatus.ready ||
      this == TripReadinessItemStatus.notApplicable;
}

enum TripReadinessSourceType {
  manual,
  offlineReadiness,
  vehicleProfile,
  routeAnalysis,
  weather,
  emergencyPlan,
}

extension TripReadinessSourceTypeX on TripReadinessSourceType {
  String get key {
    switch (this) {
      case TripReadinessSourceType.manual:
        return 'manual';
      case TripReadinessSourceType.offlineReadiness:
        return 'offline_readiness';
      case TripReadinessSourceType.vehicleProfile:
        return 'vehicle_profile';
      case TripReadinessSourceType.routeAnalysis:
        return 'route_analysis';
      case TripReadinessSourceType.weather:
        return 'weather';
      case TripReadinessSourceType.emergencyPlan:
        return 'emergency_plan';
    }
  }
}

enum TripReadinessItemType {
  offlinePackage,
  vehicleFuelOrEnergy,
  vehicleMechanicalCondition,
  vehicleTires,
  vehicleDocuments,
  personalProtectiveGear,
  personalEssentials,
  routeReviewed,
  weatherReviewed,
  connectivityReviewed,
  emergencyContacts,
  sosPrepared,
  firstAidKit,
}

extension TripReadinessItemTypeX on TripReadinessItemType {
  String get key {
    switch (this) {
      case TripReadinessItemType.offlinePackage:
        return 'offline_package';
      case TripReadinessItemType.vehicleFuelOrEnergy:
        return 'vehicle_fuel_or_energy';
      case TripReadinessItemType.vehicleMechanicalCondition:
        return 'vehicle_mechanical_condition';
      case TripReadinessItemType.vehicleTires:
        return 'vehicle_tires';
      case TripReadinessItemType.vehicleDocuments:
        return 'vehicle_documents';
      case TripReadinessItemType.personalProtectiveGear:
        return 'personal_protective_gear';
      case TripReadinessItemType.personalEssentials:
        return 'personal_essentials';
      case TripReadinessItemType.routeReviewed:
        return 'route_reviewed';
      case TripReadinessItemType.weatherReviewed:
        return 'weather_reviewed';
      case TripReadinessItemType.connectivityReviewed:
        return 'connectivity_reviewed';
      case TripReadinessItemType.emergencyContacts:
        return 'emergency_contacts';
      case TripReadinessItemType.sosPrepared:
        return 'sos_prepared';
      case TripReadinessItemType.firstAidKit:
        return 'first_aid_kit';
    }
  }

  String get label {
    switch (this) {
      case TripReadinessItemType.offlinePackage:
        return 'Dữ liệu offline';
      case TripReadinessItemType.vehicleFuelOrEnergy:
        return 'Nhiên liệu / năng lượng';
      case TripReadinessItemType.vehicleMechanicalCondition:
        return 'Tình trạng kỹ thuật';
      case TripReadinessItemType.vehicleTires:
        return 'Lốp xe';
      case TripReadinessItemType.vehicleDocuments:
        return 'Giấy tờ phương tiện';
      case TripReadinessItemType.personalProtectiveGear:
        return 'Trang bị bảo hộ';
      case TripReadinessItemType.personalEssentials:
        return 'Đồ dùng cá nhân thiết yếu';
      case TripReadinessItemType.routeReviewed:
        return 'Đã xem lại tuyến';
      case TripReadinessItemType.weatherReviewed:
        return 'Đã xem thời tiết';
      case TripReadinessItemType.connectivityReviewed:
        return 'Đã xem nguy cơ kết nối';
      case TripReadinessItemType.emergencyContacts:
        return 'Liên hệ khẩn cấp';
      case TripReadinessItemType.sosPrepared:
        return 'Chuẩn bị SOS';
      case TripReadinessItemType.firstAidKit:
        return 'Bộ sơ cứu';
    }
  }

  TripReadinessCategory get category {
    switch (this) {
      case TripReadinessItemType.offlinePackage:
        return TripReadinessCategory.offline;
      case TripReadinessItemType.vehicleFuelOrEnergy:
      case TripReadinessItemType.vehicleMechanicalCondition:
      case TripReadinessItemType.vehicleTires:
      case TripReadinessItemType.vehicleDocuments:
        return TripReadinessCategory.vehicle;
      case TripReadinessItemType.personalProtectiveGear:
      case TripReadinessItemType.personalEssentials:
        return TripReadinessCategory.personal;
      case TripReadinessItemType.routeReviewed:
      case TripReadinessItemType.weatherReviewed:
      case TripReadinessItemType.connectivityReviewed:
        return TripReadinessCategory.route;
      case TripReadinessItemType.emergencyContacts:
      case TripReadinessItemType.sosPrepared:
      case TripReadinessItemType.firstAidKit:
        return TripReadinessCategory.emergency;
    }
  }
}

class TripReadinessItem {
  const TripReadinessItem({
    required this.type,
    required this.status,
    required this.isRequired,
    required this.source,
    this.title,
    this.description,
    this.lastCheckedAt,
  });

  final TripReadinessItemType type;
  final TripReadinessItemStatus status;
  final bool isRequired;
  final TripReadinessSourceType source;
  final String? title;
  final String? description;
  final DateTime? lastCheckedAt;

  TripReadinessCategory get category => type.category;

  String get displayTitle =>
      title?.trim().isNotEmpty == true ? title!.trim() : type.label;

  bool get isReady => status.isReady;

  bool get requiresAction => status.requiresAction;

  bool get blocksReadiness =>
      isRequired &&
      (status == TripReadinessItemStatus.missing ||
          status == TripReadinessItemStatus.unknown);

  bool get preventsReady =>
      isRequired &&
      status != TripReadinessItemStatus.ready &&
      status != TripReadinessItemStatus.notApplicable;

  TripReadinessItem copyWith({
    TripReadinessItemType? type,
    TripReadinessItemStatus? status,
    bool? isRequired,
    TripReadinessSourceType? source,
    String? title,
    String? description,
    DateTime? lastCheckedAt,
  }) {
    return TripReadinessItem(
      type: type ?? this.type,
      status: status ?? this.status,
      isRequired: isRequired ?? this.isRequired,
      source: source ?? this.source,
      title: title ?? this.title,
      description: description ?? this.description,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

class TripReadinessCategorySummary {
  const TripReadinessCategorySummary({
    required this.category,
    required this.level,
    required this.score,
    required this.itemCount,
    required this.requiredItemCount,
    required this.readyRequiredItemCount,
    required this.blockingItemCount,
    required this.attentionItemCount,
  }) : assert(score >= 0 && score <= 1),
       assert(itemCount >= 0),
       assert(requiredItemCount >= 0),
       assert(readyRequiredItemCount >= 0),
       assert(blockingItemCount >= 0),
       assert(attentionItemCount >= 0);

  final TripReadinessCategory category;
  final TripReadinessLevel level;
  final double score;
  final int itemCount;
  final int requiredItemCount;
  final int readyRequiredItemCount;
  final int blockingItemCount;
  final int attentionItemCount;

  double get scorePercent => score * 100;

  bool get isReady => level.isReady;
}

class TripReadinessAssessment {
  const TripReadinessAssessment({
    required this.level,
    required this.score,
    required this.items,
    required this.categorySummaries,
    this.assessedAt,
    this.recommendedBeforeDeparture = true,
  }) : assert(score >= 0 && score <= 1);

  final TripReadinessLevel level;
  final double score;
  final List<TripReadinessItem> items;
  final List<TripReadinessCategorySummary> categorySummaries;
  final DateTime? assessedAt;
  final bool recommendedBeforeDeparture;

  double get scorePercent => score * 100;

  bool get isReady => level.isReady;

  bool get requiresAction => level.requiresAction;

  List<TripReadinessItem> get requiredItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.isRequired),
      );

  List<TripReadinessItem> get blockingItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.blocksReadiness),
      );

  List<TripReadinessItem> get actionItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.requiresAction),
      );

  bool get hasBlockingItems => blockingItems.isNotEmpty;

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

  List<TripReadinessItem> itemsForCategory(TripReadinessCategory category) {
    return List<TripReadinessItem>.unmodifiable(
      items.where((item) => item.category == category),
    );
  }

  TripReadinessCategorySummary? summaryForCategory(
    TripReadinessCategory category,
  ) {
    for (final summary in categorySummaries) {
      if (summary.category == category) {
        return summary;
      }
    }

    return null;
  }
}
