import 'connectivity_risk.dart';
import 'trip_readiness.dart';

class RouteWeatherReadinessConfirmations {
  const RouteWeatherReadinessConfirmations({
    this.routeReviewed,
    this.weatherReviewed,
    this.checkedAt,
  });

  /// null = chưa kiểm tra, true = đã xem/đồng ý với tuyến,
  /// false = tuyến còn điểm cần xem lại.
  final bool? routeReviewed;

  /// null = chưa kiểm tra, true = đã xem điều kiện thời tiết,
  /// false = còn điểm thời tiết cần xử lý trước chuyến đi.
  ///
  /// Hiện đây là xác nhận thủ công. Domain không tự khẳng định thời tiết
  /// an toàn khi chưa có weather provider chuyên biệt.
  final bool? weatherReviewed;

  final DateTime? checkedAt;

  bool get isComplete => routeReviewed != null && weatherReviewed != null;
}

class RouteWeatherReadinessEvaluation {
  const RouteWeatherReadinessEvaluation({
    required this.items,
    required this.hasRoute,
    required this.hasConnectivityAssessment,
    this.connectivityWarningRoutePercent,
  });

  final List<TripReadinessItem> items;
  final bool hasRoute;
  final bool hasConnectivityAssessment;
  final double? connectivityWarningRoutePercent;

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

class RouteWeatherReadinessEvaluator {
  const RouteWeatherReadinessEvaluator();

  RouteWeatherReadinessEvaluation evaluate({
    required bool hasRoute,
    ConnectivityRiskAssessment? connectivityAssessment,
    RouteWeatherReadinessConfirmations confirmations =
        const RouteWeatherReadinessConfirmations(),
  }) {
    final checkedAt = confirmations.checkedAt?.toUtc();

    final validConnectivityAssessment =
        connectivityAssessment != null && connectivityAssessment.hasRiskData;

    final items = <TripReadinessItem>[
      TripReadinessItem(
        type: TripReadinessItemType.routeReviewed,
        status: _routeStatus(
          hasRoute: hasRoute,
          reviewed: confirmations.routeReviewed,
        ),
        isRequired: true,
        source: hasRoute
            ? TripReadinessSourceType.manual
            : TripReadinessSourceType.routeAnalysis,
        description: hasRoute
            ? 'Xác nhận đã xem lại tuyến đường dự kiến trước khi khởi hành.'
            : 'Chưa có tuyến đường hợp lệ để kiểm tra trước chuyến đi.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.weatherReviewed,
        status: _manualReviewStatus(confirmations.weatherReviewed),
        isRequired: true,
        source: TripReadinessSourceType.weather,
        description:
            'Xác nhận đã xem điều kiện thời tiết phù hợp với thời điểm và '
            'khu vực dự kiến di chuyển. PhuotThu hiện chưa dùng weather '
            'provider chuyên biệt để tự kết luận điều kiện an toàn.',
        lastCheckedAt: checkedAt,
      ),
      TripReadinessItem(
        type: TripReadinessItemType.connectivityReviewed,
        status: validConnectivityAssessment
            ? TripReadinessItemStatus.ready
            : TripReadinessItemStatus.unknown,
        isRequired: true,
        source: TripReadinessSourceType.routeAnalysis,
        description: _connectivityDescription(
          connectivityAssessment,
          validConnectivityAssessment,
        ),
        lastCheckedAt: validConnectivityAssessment
            ? connectivityAssessment.generatedAt?.toUtc()
            : null,
      ),
    ];

    return RouteWeatherReadinessEvaluation(
      items: List<TripReadinessItem>.unmodifiable(items),
      hasRoute: hasRoute,
      hasConnectivityAssessment: validConnectivityAssessment,
      connectivityWarningRoutePercent: validConnectivityAssessment
          ? connectivityAssessment.warningRoutePercent
          : null,
    );
  }

  TripReadinessItemStatus _routeStatus({
    required bool hasRoute,
    required bool? reviewed,
  }) {
    if (!hasRoute) {
      return TripReadinessItemStatus.missing;
    }

    return _manualReviewStatus(reviewed);
  }

  TripReadinessItemStatus _manualReviewStatus(bool? reviewed) {
    if (reviewed == null) {
      return TripReadinessItemStatus.unknown;
    }

    return reviewed
        ? TripReadinessItemStatus.ready
        : TripReadinessItemStatus.needsAttention;
  }

  String _connectivityDescription(
    ConnectivityRiskAssessment? assessment,
    bool hasValidAssessment,
  ) {
    if (!hasValidAssessment || assessment == null) {
      return 'Chưa có kết quả phân tích nguy cơ kết nối cho tuyến hiện tại.';
    }

    final warningPercent = assessment.warningRoutePercent;

    if (warningPercent <= 0) {
      return 'Đã phân tích nguy cơ kết nối; chưa phát hiện đoạn HIGH/CRITICAL '
          'trong kết quả hiện tại.';
    }

    return 'Đã phân tích nguy cơ kết nối; '
        '${warningPercent.toStringAsFixed(1)}% tuyến nằm trong các đoạn '
        'HIGH/CRITICAL theo kết quả hiện tại.';
  }
}
