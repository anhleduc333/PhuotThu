import 'trip_readiness.dart';

class EmergencyReadinessConfirmations {
  const EmergencyReadinessConfirmations({
    this.emergencyContactsReady,
    this.sosPlanReviewed,
    this.firstAidKitReady,
    this.checkedAt,
  });

  /// null = chưa kiểm tra, true = đã chuẩn bị, false = chưa có/thiếu.
  final bool? emergencyContactsReady;

  /// null = chưa kiểm tra, true = đã xem và hiểu kế hoạch SOS,
  /// false = còn điểm cần chuẩn bị.
  final bool? sosPlanReviewed;

  /// null = chưa kiểm tra, true = đã chuẩn bị, false = chưa đủ.
  final bool? firstAidKitReady;

  final DateTime? checkedAt;

  bool get isComplete =>
      emergencyContactsReady != null &&
      sosPlanReviewed != null &&
      firstAidKitReady != null;
}

class EmergencyReadinessEvaluation {
  const EmergencyReadinessEvaluation({required this.items});

  static const String safetyNotice =
      'PhuotThu chỉ hỗ trợ chuẩn bị và hiển thị thông tin an toàn; '
      'không phải hệ thống cứu hộ và không cam kết tự động liên hệ '
      'cơ quan khẩn cấp.';

  final List<TripReadinessItem> items;

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

class EmergencyReadinessEvaluator {
  const EmergencyReadinessEvaluator();

  EmergencyReadinessEvaluation evaluate({
    EmergencyReadinessConfirmations confirmations =
        const EmergencyReadinessConfirmations(),
  }) {
    final checkedAt = confirmations.checkedAt?.toUtc();

    final items = <TripReadinessItem>[
      TripReadinessItem(
        type: TripReadinessItemType.emergencyContacts,
        status: _contactsStatus(confirmations.emergencyContactsReady),
        isRequired: true,
        source: TripReadinessSourceType.emergencyPlan,
        description:
            'Xác nhận đã chuẩn bị ít nhất một phương án liên hệ khẩn cấp '
            'hoặc người thân có thể liên hệ khi cần.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.sosPrepared,
        status: _attentionStatus(confirmations.sosPlanReviewed),
        isRequired: true,
        source: TripReadinessSourceType.emergencyPlan,
        description:
            'Xác nhận đã xem cách xử lý khi cần trợ giúp: chia sẻ vị trí, '
            'liên hệ người thân hoặc sử dụng kênh khẩn cấp phù hợp. '
            'PhuotThu không tự động điều phối cứu hộ.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.firstAidKit,
        status: _attentionStatus(confirmations.firstAidKitReady),
        isRequired: true,
        source: TripReadinessSourceType.emergencyPlan,
        description:
            'Xác nhận đã chuẩn bị bộ sơ cứu cơ bản phù hợp với chuyến đi. '
            'Checklist này không thay thế hướng dẫn hoặc đánh giá y tế.',
        lastCheckedAt: checkedAt,
      ),
    ];

    return EmergencyReadinessEvaluation(
      items: List<TripReadinessItem>.unmodifiable(items),
    );
  }

  TripReadinessItemStatus _contactsStatus(bool? value) {
    if (value == null) {
      return TripReadinessItemStatus.unknown;
    }

    return value
        ? TripReadinessItemStatus.ready
        : TripReadinessItemStatus.missing;
  }

  TripReadinessItemStatus _attentionStatus(bool? value) {
    if (value == null) {
      return TripReadinessItemStatus.unknown;
    }

    return value
        ? TripReadinessItemStatus.ready
        : TripReadinessItemStatus.needsAttention;
  }
}
