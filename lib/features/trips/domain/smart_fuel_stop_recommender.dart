import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';
import 'fuel_range_calculator.dart';
import 'route_progress_calculator.dart';

class SmartFuelStopRecommendation {
  const SmartFuelStopRecommendation({
    required this.stopNumber,
    required this.place,
    required this.progress,
    required this.distanceSincePreviousStopMeters,
    required this.safeLimitFromStartMeters,
    required this.marginBeforeSafeLimitMeters,
  });

  final int stopNumber;

  /// Cây xăng được đề xuất.
  final AlongRoutePlace place;

  /// Vị trí của cây xăng trên hành trình.
  final RouteProgressEstimate progress;

  /// Quãng đường đi từ điểm xuất phát hoặc điểm đổ xăng
  /// trước đó đến cây xăng này.
  final double distanceSincePreviousStopMeters;

  /// Vị trí giới hạn an toàn trên toàn tuyến tại thời điểm
  /// phải tìm điểm đổ xăng.
  final double safeLimitFromStartMeters;

  /// Khoảng cách còn lại trước khi chạm ngưỡng an toàn.
  ///
  /// Ví dụ:
  /// safe limit = km 173
  /// cây xăng = km 168
  /// margin = 5 km.
  final double marginBeforeSafeLimitMeters;

  double get distanceSincePreviousStopKm =>
      distanceSincePreviousStopMeters / 1000;

  double get safeLimitFromStartKm => safeLimitFromStartMeters / 1000;

  double get marginBeforeSafeLimitKm => marginBeforeSafeLimitMeters / 1000;
}

class SmartFuelPlan {
  const SmartFuelPlan({
    required this.fuelStopRequired,
    required this.routeFullyCovered,
    required this.totalRouteMeters,
    required this.initialSafeRangeMeters,
    required this.fullTankSafeRangeMeters,
    required this.recommendations,
    this.uncoveredFromMeters,
  });

  /// Tuyến có dài hơn tầm hoạt động an toàn ban đầu không.
  final bool fuelStopRequired;

  /// Có đủ cây xăng để tạo một chuỗi điểm dừng an toàn
  /// đến đích hay không.
  final bool routeFullyCovered;

  final double totalRouteMeters;

  /// Tầm hoạt động an toàn tại thời điểm xuất phát.
  ///
  /// Giá trị này phụ thuộc startingFuelRatio.
  final double initialSafeRangeMeters;

  /// Tầm hoạt động an toàn sau khi đổ đầy bình.
  final double fullTankSafeRangeMeters;

  final List<SmartFuelStopRecommendation> recommendations;

  /// Khi không thể đi tiếp an toàn, đây là vị trí của
  /// điểm xuất phát / cây xăng cuối cùng đã tới được.
  final double? uncoveredFromMeters;

  double get totalRouteKm => totalRouteMeters / 1000;

  double get initialSafeRangeKm => initialSafeRangeMeters / 1000;

  double get fullTankSafeRangeKm => fullTankSafeRangeMeters / 1000;

  double? get uncoveredFromKm =>
      uncoveredFromMeters == null ? null : uncoveredFromMeters! / 1000;
}

class SmartFuelStopRecommender {
  const SmartFuelStopRecommender();

  static const double _defaultMaxCorridorMeters = 2000;

  static const double _minimumForwardProgressMeters = 500;

  static const int _maximumRecommendedStops = 20;

  SmartFuelPlan? recommend({
    required List<RoutePoint> routePoints,
    required List<AlongRoutePlace> places,
    required FuelRangeEstimate fuelRange,
    double maxCorridorMeters = _defaultMaxCorridorMeters,
  }) {
    if (routePoints.length < 2) {
      return null;
    }

    if (fuelRange.tankCapacityLiters <= 0 ||
        fuelRange.consumptionLitersPer100Km <= 0) {
      return null;
    }

    if (maxCorridorMeters < 0) {
      return null;
    }

    const progressCalculator = RouteProgressCalculator();

    final routeSummary = progressCalculator.calculate(
      routePoints: routePoints,
      latitude: routePoints.first.latitude,
      longitude: routePoints.first.longitude,
    );

    if (routeSummary == null || routeSummary.totalRouteMeters <= 0) {
      return null;
    }

    final totalRouteMeters = routeSummary.totalRouteMeters;

    final initialSafeRangeMeters = fuelRange.safeRangeMeters;

    final fullTankUsableFuelLiters =
        fuelRange.tankCapacityLiters * (1 - fuelRange.reserveRatio);

    final fullTankSafeRangeMeters =
        fullTankUsableFuelLiters /
        fuelRange.consumptionLitersPer100Km *
        100 *
        1000;

    final fuelStopRequired = totalRouteMeters > initialSafeRangeMeters;

    if (!fuelStopRequired) {
      return SmartFuelPlan(
        fuelStopRequired: false,
        routeFullyCovered: true,
        totalRouteMeters: totalRouteMeters,
        initialSafeRangeMeters: initialSafeRangeMeters,
        fullTankSafeRangeMeters: fullTankSafeRangeMeters,
        recommendations: const [],
      );
    }

    final candidates = <_FuelStopCandidate>[];

    final seenSourceIds = <String>{};

    for (final place in places) {
      if (place.type != AlongRoutePlaceType.fuel) {
        continue;
      }

      if (!seenSourceIds.add(place.sourceId)) {
        continue;
      }

      final progress = progressCalculator.calculate(
        routePoints: routePoints,
        latitude: place.latitude,
        longitude: place.longitude,
      );

      if (progress == null) {
        continue;
      }

      if (!progress.isWithinCorridorMeters(maxCorridorMeters)) {
        continue;
      }

      if (progress.distanceFromStartMeters <= _minimumForwardProgressMeters ||
          progress.distanceFromStartMeters >=
              totalRouteMeters - _minimumForwardProgressMeters) {
        continue;
      }

      candidates.add(_FuelStopCandidate(place: place, progress: progress));
    }

    candidates.sort((a, b) {
      final progressCompare = a.progress.distanceFromStartMeters.compareTo(
        b.progress.distanceFromStartMeters,
      );

      if (progressCompare != 0) {
        return progressCompare;
      }

      return a.progress.distanceFromRouteMeters.compareTo(
        b.progress.distanceFromRouteMeters,
      );
    });

    final recommendations = <SmartFuelStopRecommendation>[];

    var currentDistanceFromStart = 0.0;

    var availableSafeRange = initialSafeRangeMeters;

    var stopNumber = 1;

    while (currentDistanceFromStart < totalRouteMeters &&
        recommendations.length < _maximumRecommendedStops) {
      final safeLimit = currentDistanceFromStart + availableSafeRange;

      if (totalRouteMeters <= safeLimit) {
        return SmartFuelPlan(
          fuelStopRequired: true,
          routeFullyCovered: true,
          totalRouteMeters: totalRouteMeters,
          initialSafeRangeMeters: initialSafeRangeMeters,
          fullTankSafeRangeMeters: fullTankSafeRangeMeters,
          recommendations: List<SmartFuelStopRecommendation>.unmodifiable(
            recommendations,
          ),
        );
      }

      _FuelStopCandidate? selected;

      for (final candidate in candidates) {
        final stationDistance = candidate.progress.distanceFromStartMeters;

        if (stationDistance <=
            currentDistanceFromStart + _minimumForwardProgressMeters) {
          continue;
        }

        if (stationDistance > safeLimit) {
          break;
        }

        if (selected == null) {
          selected = candidate;
          continue;
        }

        final selectedProgress = selected.progress.distanceFromStartMeters;

        /// Ưu tiên cây xăng xa nhất nhưng vẫn nằm
        /// trong tầm hoạt động an toàn.
        ///
        /// Khi hai cây xăng gần như cùng km trên tuyến,
        /// ưu tiên cây xăng nằm gần tuyến hơn.
        if (stationDistance > selectedProgress + 50) {
          selected = candidate;
          continue;
        }

        if ((stationDistance - selectedProgress).abs() <= 50) {
          if (candidate.progress.distanceFromRouteMeters <
              selected.progress.distanceFromRouteMeters) {
            selected = candidate;
          }
        }
      }

      if (selected == null) {
        return SmartFuelPlan(
          fuelStopRequired: true,
          routeFullyCovered: false,
          totalRouteMeters: totalRouteMeters,
          initialSafeRangeMeters: initialSafeRangeMeters,
          fullTankSafeRangeMeters: fullTankSafeRangeMeters,
          recommendations: List<SmartFuelStopRecommendation>.unmodifiable(
            recommendations,
          ),
          uncoveredFromMeters: currentDistanceFromStart,
        );
      }

      final stationDistance = selected.progress.distanceFromStartMeters;

      recommendations.add(
        SmartFuelStopRecommendation(
          stopNumber: stopNumber,
          place: selected.place,
          progress: selected.progress,
          distanceSincePreviousStopMeters:
              stationDistance - currentDistanceFromStart,
          safeLimitFromStartMeters: safeLimit,
          marginBeforeSafeLimitMeters: safeLimit - stationDistance,
        ),
      );

      currentDistanceFromStart = stationDistance;

      /// Sau khi dừng tại cây xăng được đề xuất,
      /// giả định người dùng đổ đầy bình.
      availableSafeRange = fullTankSafeRangeMeters;

      stopNumber++;
    }

    return SmartFuelPlan(
      fuelStopRequired: true,
      routeFullyCovered:
          totalRouteMeters <= currentDistanceFromStart + availableSafeRange,
      totalRouteMeters: totalRouteMeters,
      initialSafeRangeMeters: initialSafeRangeMeters,
      fullTankSafeRangeMeters: fullTankSafeRangeMeters,
      recommendations: List<SmartFuelStopRecommendation>.unmodifiable(
        recommendations,
      ),
      uncoveredFromMeters:
          totalRouteMeters > currentDistanceFromStart + availableSafeRange
          ? currentDistanceFromStart
          : null,
    );
  }
}

class _FuelStopCandidate {
  const _FuelStopCandidate({required this.place, required this.progress});

  final AlongRoutePlace place;
  final RouteProgressEstimate progress;
}
