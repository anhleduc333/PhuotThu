import 'offline_readiness.dart';
import 'offline_readiness_scorer.dart';
import 'offline_trip_package_snapshot.dart';

class OfflineReadinessEvaluator {
  const OfflineReadinessEvaluator({
    this.scorer = const OfflineReadinessScorer(),
  });

  final OfflineReadinessScorer scorer;

  OfflineReadinessScoringResult evaluate({
    required OfflineTripPackageSnapshot? snapshot,
    bool packageNeedsRefresh = false,
    DateTime? assessedAt,
  }) {
    final items = <OfflineReadinessItem>[
      _packageBackedItem(
        type: OfflineReadinessItemType.tripDetails,
        hasData: snapshot != null,
        isRequired: true,
        packageNeedsRefresh: packageNeedsRefresh,
        lastUpdatedAt: snapshot?.savedAt,
        description: 'Thông tin điểm đầu, điểm đến, phương tiện, thời gian và ngân sách.',
      ),
      _packageBackedItem(
        type: OfflineReadinessItemType.routeGeometry,
        hasData: snapshot != null && snapshot.route.points.length >= 2,
        isRequired: true,
        packageNeedsRefresh: packageNeedsRefresh,
        lastUpdatedAt: snapshot?.savedAt,
        description: 'Polyline tuyến được lưu cục bộ để vẫn xem được hành trình khi mất mạng.',
      ),
      _packageBackedItem(
        type: OfflineReadinessItemType.routeSummary,
        hasData:
            snapshot != null &&
            snapshot.route.distanceMeters > 0 &&
            snapshot.route.durationSeconds > 0,
        isRequired: true,
        packageNeedsRefresh: packageNeedsRefresh,
        lastUpdatedAt: snapshot?.savedAt,
        description: 'Khoảng cách và thời gian dự kiến của tuyến.',
      ),
      _packageBackedItem(
        type: OfflineReadinessItemType.essentialPois,
        hasData: snapshot != null && snapshot.pois.isNotEmpty,
        isRequired: false,
        packageNeedsRefresh: packageNeedsRefresh,
        lastUpdatedAt: snapshot?.savedAt,
        description: 'Cây xăng, ăn uống, lưu trú, sửa chữa hoặc y tế đã tìm được dọc tuyến.',
      ),
      const OfflineReadinessItem(
        type: OfflineReadinessItemType.emergencyInfo,
        status: OfflineReadinessItemStatus.notApplicable,
        isRequired: false,
        description:
            'Chưa có gói thông tin khẩn cấp offline trong phiên bản hiện tại.',
      ),
      _packageBackedItem(
        type: OfflineReadinessItemType.connectivityRiskAnalysis,
        hasData: snapshot?.connectivity != null,
        isRequired: false,
        packageNeedsRefresh: packageNeedsRefresh,
        lastUpdatedAt: snapshot?.connectivity?.generatedAt ?? snapshot?.savedAt,
        description: 'Kết quả ước lượng nguy cơ kết nối đã lưu cùng chuyến đi.',
      ),
      const OfflineReadinessItem(
        type: OfflineReadinessItemType.offlineMap,
        status: OfflineReadinessItemStatus.notApplicable,
        isRequired: false,
        title: 'Bản đồ nền offline',
        description:
            'Tile nền OpenStreetMap chưa được cache trong phiên bản hiện tại.',
      ),
    ];

    final result = scorer.score(
      items: items,
      connectivityWarningRoutePercent:
          snapshot?.connectivity?.warningRoutePercent,
      assessedAt: assessedAt ?? DateTime.now().toUtc(),
    );

    if (result == null) {
      throw StateError('Không thể đánh giá mức sẵn sàng offline.');
    }

    return result;
  }

  OfflineReadinessItem _packageBackedItem({
    required OfflineReadinessItemType type,
    required bool hasData,
    required bool isRequired,
    required bool packageNeedsRefresh,
    required String description,
    DateTime? lastUpdatedAt,
  }) {
    final status = !hasData
        ? OfflineReadinessItemStatus.missing
        : packageNeedsRefresh
        ? OfflineReadinessItemStatus.stale
        : OfflineReadinessItemStatus.ready;

    return OfflineReadinessItem(
      type: type,
      status: status,
      isRequired: isRequired,
      description: description,
      lastUpdatedAt: lastUpdatedAt,
    );
  }
}
