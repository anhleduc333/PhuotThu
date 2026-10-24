import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';
import 'rest_policy_calculator.dart';
import 'route_progress_calculator.dart';

class RestCandidateScoringPolicy {
  const RestCandidateScoringPolicy({
    this.targetProximityWeight = 0.55,
    this.routeDeviationWeight = 0.30,
    this.placeSuitabilityWeight = 0.15,
    this.maxTargetDistanceMeters = 20000,
    this.maxRouteDeviationMeters = 2000,
    this.maxResults = 10,
  });

  /// Trọng số mức độ gần mốc nghỉ mục tiêu.
  final double targetProximityWeight;

  /// Trọng số mức độ ít lệch khỏi tuyến.
  final double routeDeviationWeight;

  /// Trọng số mức phù hợp của loại địa điểm.
  final double placeSuitabilityWeight;

  /// POI phải nằm trong khoảng ±20 km quanh
  /// mốc nghỉ mục tiêu.
  final double maxTargetDistanceMeters;

  /// POI không được lệch tuyến quá 2 km.
  final double maxRouteDeviationMeters;

  /// Số ứng viên tối đa trả về cho một mốc nghỉ.
  final int maxResults;

  bool get isValid {
    if (targetProximityWeight < 0 ||
        routeDeviationWeight < 0 ||
        placeSuitabilityWeight < 0) {
      return false;
    }

    final totalWeight =
        targetProximityWeight + routeDeviationWeight + placeSuitabilityWeight;

    return totalWeight > 0 &&
        maxTargetDistanceMeters > 0 &&
        maxRouteDeviationMeters > 0 &&
        maxResults > 0;
  }

  double get totalWeight =>
      targetProximityWeight + routeDeviationWeight + placeSuitabilityWeight;
}

class RestCandidateScore {
  const RestCandidateScore({
    required this.targetProximity,
    required this.routeDeviation,
    required this.placeSuitability,
    required this.total,
  });

  /// Điểm thành phần từ 0.0 đến 1.0.
  final double targetProximity;

  /// Điểm thành phần từ 0.0 đến 1.0.
  final double routeDeviation;

  /// Điểm thành phần từ 0.0 đến 1.0.
  final double placeSuitability;

  /// Điểm tổng từ 0 đến 100.
  final double total;
}

class RestCandidate {
  const RestCandidate({
    required this.place,
    required this.progress,
    required this.distanceFromTargetMeters,
    required this.score,
  });

  final AlongRoutePlace place;

  /// Vị trí POI trên toàn tuyến.
  final RouteProgressEstimate progress;

  /// POI cách mốc nghỉ lý tưởng bao nhiêu mét
  /// theo chiều dài của tuyến.
  final double distanceFromTargetMeters;

  final RestCandidateScore score;

  double get distanceFromTargetKm => distanceFromTargetMeters / 1000;

  double get routePositionKm => progress.distanceFromStartKm;
}

class RestCandidateScorer {
  const RestCandidateScorer();

  List<RestCandidate> score({
    required RestTarget target,
    required List<RoutePoint> routePoints,
    required List<AlongRoutePlace> places,
    RestCandidateScoringPolicy policy = const RestCandidateScoringPolicy(),
    Set<AlongRoutePlaceType> eligibleTypes = const {
      AlongRoutePlaceType.restArea,
      AlongRoutePlaceType.food,
    },
  }) {
    if (routePoints.length < 2 ||
        places.isEmpty ||
        eligibleTypes.isEmpty ||
        !policy.isValid) {
      return const [];
    }

    const progressCalculator = RouteProgressCalculator();

    final candidates = <RestCandidate>[];

    final seenSourceIds = <String>{};

    for (final place in places) {
      if (!eligibleTypes.contains(place.type)) {
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

      if (!progress.isWithinCorridorMeters(policy.maxRouteDeviationMeters)) {
        continue;
      }

      final distanceFromTargetMeters =
          (progress.distanceFromStartMeters - target.targetDistanceMeters)
              .abs();

      if (distanceFromTargetMeters > policy.maxTargetDistanceMeters) {
        continue;
      }

      final targetProximityScore = _inverseLinearScore(
        value: distanceFromTargetMeters,
        maximum: policy.maxTargetDistanceMeters,
      );

      final routeDeviationScore = _inverseLinearScore(
        value: progress.distanceFromRouteMeters,
        maximum: policy.maxRouteDeviationMeters,
      );

      final suitabilityScore = _placeSuitabilityScore(place);

      final weightedScore =
          (targetProximityScore * policy.targetProximityWeight +
              routeDeviationScore * policy.routeDeviationWeight +
              suitabilityScore * policy.placeSuitabilityWeight) /
          policy.totalWeight;

      candidates.add(
        RestCandidate(
          place: place,
          progress: progress,
          distanceFromTargetMeters: distanceFromTargetMeters,
          score: RestCandidateScore(
            targetProximity: targetProximityScore,
            routeDeviation: routeDeviationScore,
            placeSuitability: suitabilityScore,
            total: weightedScore * 100,
          ),
        ),
      );
    }

    candidates.sort((a, b) {
      final totalScoreCompare = b.score.total.compareTo(a.score.total);

      if (totalScoreCompare != 0) {
        return totalScoreCompare;
      }

      final targetDistanceCompare = a.distanceFromTargetMeters.compareTo(
        b.distanceFromTargetMeters,
      );

      if (targetDistanceCompare != 0) {
        return targetDistanceCompare;
      }

      final routeDistanceCompare = a.progress.distanceFromRouteMeters.compareTo(
        b.progress.distanceFromRouteMeters,
      );

      if (routeDistanceCompare != 0) {
        return routeDistanceCompare;
      }

      return a.place.name.toLowerCase().compareTo(b.place.name.toLowerCase());
    });

    return List<RestCandidate>.unmodifiable(candidates.take(policy.maxResults));
  }

  double _inverseLinearScore({required double value, required double maximum}) {
    if (value <= 0) {
      return 1;
    }

    if (value >= maximum) {
      return 0;
    }

    return 1 - value / maximum;
  }

  double _placeSuitabilityScore(AlongRoutePlace place) {
    switch (place.type) {
      case AlongRoutePlaceType.restArea:
        return 1;

      case AlongRoutePlaceType.food:
        return _foodSuitabilityScore(place);

      case AlongRoutePlaceType.fuel:
      case AlongRoutePlaceType.repair:
      case AlongRoutePlaceType.medical:
        return 0;
    }
  }

  double _foodSuitabilityScore(AlongRoutePlace place) {
    final categories = (place.tags['categories'] ?? '').toLowerCase();

    if (categories.contains('catering.cafe')) {
      return 0.95;
    }

    if (categories.contains('catering.restaurant')) {
      return 0.85;
    }

    if (categories.contains('catering.food_court')) {
      return 0.85;
    }

    if (categories.contains('catering.fast_food')) {
      return 0.70;
    }

    return 0.75;
  }
}
