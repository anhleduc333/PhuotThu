import '../../map/domain/along_route_place.dart';
import '../../map/domain/route_result.dart';
import 'rest_candidate_scorer.dart';
import 'rest_policy_calculator.dart';

class SmartRestStopRecommendation {
  const SmartRestStopRecommendation({
    required this.stopNumber,
    required this.target,
    required this.candidate,
  });

  final int stopNumber;

  /// Mốc nghỉ lý tưởng do RestPolicyCalculator tạo ra.
  final RestTarget target;

  /// POI thực tế được chọn cho mốc nghỉ này.
  final RestCandidate candidate;

  AlongRoutePlace get place => candidate.place;

  double get routePositionKm => candidate.routePositionKm;

  double get distanceFromTargetKm => candidate.distanceFromTargetKm;

  double get routeDeviationMeters => candidate.progress.distanceFromRouteMeters;

  double get score => candidate.score.total;
}

class SmartRestPlan {
  const SmartRestPlan({
    required this.restRequired,
    required this.allTargetsCovered,
    required this.restPlan,
    required this.recommendations,
    required this.uncoveredTargets,
  });

  /// Tuyến có phát sinh nhu cầu nghỉ hay không.
  final bool restRequired;

  /// Tất cả mốc nghỉ có tìm được POI phù hợp hay không.
  final bool allTargetsCovered;

  /// Kế hoạch mốc nghỉ lý tưởng.
  final RestPlan restPlan;

  /// Các điểm nghỉ thực tế được đề xuất.
  final List<SmartRestStopRecommendation> recommendations;

  /// Các mốc nghỉ chưa tìm được POI phù hợp.
  final List<RestTarget> uncoveredTargets;

  int get targetCount => restPlan.targets.length;

  int get recommendationCount => recommendations.length;

  int get uncoveredTargetCount => uncoveredTargets.length;
}

class SmartRestStopRecommender {
  const SmartRestStopRecommender();

  static const double _minimumForwardProgressMeters = 500;

  SmartRestPlan? recommend({
    required List<RoutePoint> routePoints,
    required int distanceMeters,
    required int durationSeconds,
    required List<AlongRoutePlace> places,
    RestPolicy restPolicy = const RestPolicy(),
    RestCandidateScoringPolicy scoringPolicy =
        const RestCandidateScoringPolicy(),
    Set<AlongRoutePlaceType> eligibleTypes = const {
      AlongRoutePlaceType.restArea,
      AlongRoutePlaceType.food,
    },
  }) {
    if (routePoints.length < 2 || eligibleTypes.isEmpty) {
      return null;
    }

    const policyCalculator = RestPolicyCalculator();

    final restPlan = policyCalculator.calculate(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      policy: restPolicy,
    );

    if (restPlan == null) {
      return null;
    }

    if (!restPlan.restRecommended) {
      return SmartRestPlan(
        restRequired: false,
        allTargetsCovered: true,
        restPlan: restPlan,
        recommendations: const [],
        uncoveredTargets: const [],
      );
    }

    const scorer = RestCandidateScorer();

    final recommendations = <SmartRestStopRecommendation>[];

    final uncoveredTargets = <RestTarget>[];

    final usedSourceIds = <String>{};

    var previousStopDistanceMeters = -double.infinity;

    for (final target in restPlan.targets) {
      final candidates = scorer.score(
        target: target,
        routePoints: routePoints,
        places: places,
        policy: scoringPolicy,
        eligibleTypes: eligibleTypes,
      );

      RestCandidate? selected;

      for (final candidate in candidates) {
        if (usedSourceIds.contains(candidate.place.sourceId)) {
          continue;
        }

        final candidateProgress = candidate.progress.distanceFromStartMeters;

        if (previousStopDistanceMeters.isFinite &&
            candidateProgress <=
                previousStopDistanceMeters + _minimumForwardProgressMeters) {
          continue;
        }

        selected = candidate;
        break;
      }

      if (selected == null) {
        uncoveredTargets.add(target);

        continue;
      }

      usedSourceIds.add(selected.place.sourceId);

      previousStopDistanceMeters = selected.progress.distanceFromStartMeters;

      recommendations.add(
        SmartRestStopRecommendation(
          stopNumber: recommendations.length + 1,
          target: target,
          candidate: selected,
        ),
      );
    }

    return SmartRestPlan(
      restRequired: true,
      allTargetsCovered: uncoveredTargets.isEmpty,
      restPlan: restPlan,
      recommendations: List<SmartRestStopRecommendation>.unmodifiable(
        recommendations,
      ),
      uncoveredTargets: List<RestTarget>.unmodifiable(uncoveredTargets),
    );
  }
}
