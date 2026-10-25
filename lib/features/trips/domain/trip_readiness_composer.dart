import '../../vehicle/domain/vehicle.dart';
import 'connectivity_risk.dart';
import 'emergency_readiness.dart';
import 'offline_readiness.dart';
import 'offline_trip_readiness_adapter.dart';
import 'personal_readiness.dart';
import 'route_weather_readiness.dart';
import 'trip_readiness.dart';
import 'trip_readiness_checklist_snapshot.dart';
import 'trip_readiness_scorer.dart';
import 'vehicle_readiness.dart';

class TripReadinessComposition {
  const TripReadinessComposition({
    required this.scoring,
    required this.vehicle,
    required this.personal,
    required this.routeWeather,
    required this.emergency,
  });

  final TripReadinessScoringResult scoring;
  final VehicleReadinessEvaluation vehicle;
  final PersonalReadinessEvaluation personal;
  final RouteWeatherReadinessEvaluation routeWeather;
  final EmergencyReadinessEvaluation emergency;
}

class TripReadinessComposer {
  const TripReadinessComposer();

  TripReadinessComposition compose({
    required OfflineReadinessAssessment offlineAssessment,
    required TripReadinessChecklistSnapshot checklist,
    required Vehicle? vehicle,
    required bool hasRoute,
    ConnectivityRiskAssessment? connectivityAssessment,
    DateTime? assessedAt,
    TripReadinessScoringPolicy scoringPolicy =
        const TripReadinessScoringPolicy(),
  }) {
    const offlineAdapter = OfflineTripReadinessAdapter();
    const vehicleEvaluator = VehicleReadinessEvaluator();
    const personalEvaluator = PersonalReadinessEvaluator();
    const routeWeatherEvaluator = RouteWeatherReadinessEvaluator();
    const emergencyEvaluator = EmergencyReadinessEvaluator();
    const scorer = TripReadinessScorer();

    final offlineItem = offlineAdapter.adapt(offlineAssessment);

    final vehicleEvaluation = vehicleEvaluator.evaluate(
      vehicle: vehicle,
      confirmations: checklist.vehicle,
    );

    final personalEvaluation = personalEvaluator.evaluate(
      confirmations: checklist.personal,
    );

    final routeWeatherEvaluation = routeWeatherEvaluator.evaluate(
      hasRoute: hasRoute,
      connectivityAssessment: connectivityAssessment,
      confirmations: checklist.routeWeather,
    );

    final emergencyEvaluation = emergencyEvaluator.evaluate(
      confirmations: checklist.emergency,
    );

    final items = [
      offlineItem,
      ...vehicleEvaluation.items,
      ...personalEvaluation.items,
      ...routeWeatherEvaluation.items,
      ...emergencyEvaluation.items,
    ];

    final scoring = scorer.score(
      items: items,
      assessedAt: assessedAt,
      policy: scoringPolicy,
      categoryScoreOverrides: {
        TripReadinessCategory.offline: offlineAssessment.score,
      },
    );

    if (scoring == null) {
      throw StateError('Không thể tính Trip Readiness từ dữ liệu hiện tại.');
    }

    return TripReadinessComposition(
      scoring: scoring,
      vehicle: vehicleEvaluation,
      personal: personalEvaluation,
      routeWeather: routeWeatherEvaluation,
      emergency: emergencyEvaluation,
    );
  }
}
