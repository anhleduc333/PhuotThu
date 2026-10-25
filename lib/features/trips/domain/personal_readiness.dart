import 'trip_readiness.dart';

enum PersonalReadinessCheckType { protectiveGear, personalEssentials }

extension PersonalReadinessCheckTypeX on PersonalReadinessCheckType {
  String get key {
    switch (this) {
      case PersonalReadinessCheckType.protectiveGear:
        return 'protective_gear';
      case PersonalReadinessCheckType.personalEssentials:
        return 'personal_essentials';
    }
  }

  String get label {
    switch (this) {
      case PersonalReadinessCheckType.protectiveGear:
        return 'Trang bị bảo hộ';
      case PersonalReadinessCheckType.personalEssentials:
        return 'Đồ dùng cá nhân thiết yếu';
    }
  }
}

class PersonalReadinessConfirmations {
  const PersonalReadinessConfirmations({
    this.protectiveGearReady,
    this.personalEssentialsReady,
    this.checkedAt,
  });

  /// null = chưa kiểm tra, true = sẵn sàng, false = cần chuẩn bị thêm.
  final bool? protectiveGearReady;

  /// null = chưa kiểm tra, true = sẵn sàng, false = cần chuẩn bị thêm.
  final bool? personalEssentialsReady;

  final DateTime? checkedAt;

  bool get isComplete =>
      protectiveGearReady != null && personalEssentialsReady != null;
}

class PersonalReadinessEvaluation {
  const PersonalReadinessEvaluation({required this.items});

  final List<TripReadinessItem> items;

  List<TripReadinessItem> get actionItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.requiresAction),
      );

  List<TripReadinessItem> get uncheckedItems =>
      List<TripReadinessItem>.unmodifiable(
        items.where((item) => item.status == TripReadinessItemStatus.unknown),
      );

  int get readyCount => items.where((item) => item.isReady).length;

  bool get allRequiredReady =>
      items.where((item) => item.isRequired).every((item) => item.isReady);
}

class PersonalReadinessEvaluator {
  const PersonalReadinessEvaluator();

  PersonalReadinessEvaluation evaluate({
    PersonalReadinessConfirmations confirmations =
        const PersonalReadinessConfirmations(),
  }) {
    final checkedAt = confirmations.checkedAt?.toUtc();

    final items = <TripReadinessItem>[
      TripReadinessItem(
        type: TripReadinessItemType.personalProtectiveGear,
        status: _status(confirmations.protectiveGearReady),
        isRequired: true,
        source: TripReadinessSourceType.manual,
        description:
            'Xác nhận đã chuẩn bị trang bị bảo hộ phù hợp cho chuyến đi. '
            'PhuotThu chỉ ghi nhận checklist do người dùng xác nhận.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.personalEssentials,
        status: _status(confirmations.personalEssentialsReady),
        isRequired: true,
        source: TripReadinessSourceType.manual,
        description:
            'Xác nhận đã chuẩn bị các đồ dùng cá nhân thiết yếu cần mang '
            'theo cho hành trình.',
        lastCheckedAt: checkedAt,
      ),
    ];

    return PersonalReadinessEvaluation(
      items: List<TripReadinessItem>.unmodifiable(items),
    );
  }

  TripReadinessItemStatus _status(bool? value) {
    if (value == null) {
      return TripReadinessItemStatus.unknown;
    }

    return value
        ? TripReadinessItemStatus.ready
        : TripReadinessItemStatus.needsAttention;
  }
}
