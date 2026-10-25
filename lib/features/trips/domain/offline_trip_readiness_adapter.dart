import 'offline_readiness.dart';
import 'trip_readiness.dart';

class OfflineTripReadinessAdapter {
  const OfflineTripReadinessAdapter();

  TripReadinessItem adapt(OfflineReadinessAssessment assessment) {
    return TripReadinessItem(
      type: TripReadinessItemType.offlinePackage,
      status: _mapStatus(assessment.level),
      isRequired: true,
      source: TripReadinessSourceType.offlineReadiness,
      description: _description(assessment),
      lastCheckedAt: assessment.assessedAt?.toUtc(),
    );
  }

  TripReadinessItemStatus _mapStatus(OfflineReadinessLevel level) {
    switch (level) {
      case OfflineReadinessLevel.unknown:
        return TripReadinessItemStatus.unknown;
      case OfflineReadinessLevel.notReady:
        return TripReadinessItemStatus.missing;
      case OfflineReadinessLevel.needsAttention:
        return TripReadinessItemStatus.needsAttention;
      case OfflineReadinessLevel.ready:
        return TripReadinessItemStatus.ready;
    }
  }

  String _description(OfflineReadinessAssessment assessment) {
    final score = assessment.scorePercent.round().clamp(0, 100);

    final warningPercent = assessment.connectivityWarningRoutePercent;

    if (warningPercent == null) {
      return 'Mức sẵn sàng offline hiện tại: $score%.';
    }

    return 'Mức sẵn sàng offline hiện tại: $score%. '
        'Đoạn HIGH/CRITICAL: '
        '${warningPercent.toStringAsFixed(1)}% tuyến.';
  }
}
