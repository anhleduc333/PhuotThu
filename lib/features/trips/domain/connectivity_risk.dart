enum ConnectivityRiskLevel { unknown, low, moderate, high, critical }

extension ConnectivityRiskLevelX on ConnectivityRiskLevel {
  String get key {
    switch (this) {
      case ConnectivityRiskLevel.unknown:
        return 'unknown';
      case ConnectivityRiskLevel.low:
        return 'low';
      case ConnectivityRiskLevel.moderate:
        return 'moderate';
      case ConnectivityRiskLevel.high:
        return 'high';
      case ConnectivityRiskLevel.critical:
        return 'critical';
    }
  }

  String get label {
    switch (this) {
      case ConnectivityRiskLevel.unknown:
        return 'Chưa xác định';
      case ConnectivityRiskLevel.low:
        return 'Thấp';
      case ConnectivityRiskLevel.moderate:
        return 'Trung bình';
      case ConnectivityRiskLevel.high:
        return 'Cao';
      case ConnectivityRiskLevel.critical:
        return 'Rất cao';
    }
  }

  bool get requiresWarning {
    return this == ConnectivityRiskLevel.high ||
        this == ConnectivityRiskLevel.critical;
  }

  int get severity {
    switch (this) {
      case ConnectivityRiskLevel.unknown:
        return -1;
      case ConnectivityRiskLevel.low:
        return 0;
      case ConnectivityRiskLevel.moderate:
        return 1;
      case ConnectivityRiskLevel.high:
        return 2;
      case ConnectivityRiskLevel.critical:
        return 3;
    }
  }

  static ConnectivityRiskLevel fromScore(double? score) {
    if (score == null || !score.isFinite || score < 0 || score > 1) {
      return ConnectivityRiskLevel.unknown;
    }

    if (score < 0.25) {
      return ConnectivityRiskLevel.low;
    }

    if (score < 0.50) {
      return ConnectivityRiskLevel.moderate;
    }

    if (score < 0.75) {
      return ConnectivityRiskLevel.high;
    }

    return ConnectivityRiskLevel.critical;
  }
}

enum ConnectivityRiskEvidenceType {
  mobileCoverage,
  terrain,
  settlementDensity,
  roadIsolation,
  manual,
}

extension ConnectivityRiskEvidenceTypeX on ConnectivityRiskEvidenceType {
  String get key {
    switch (this) {
      case ConnectivityRiskEvidenceType.mobileCoverage:
        return 'mobile_coverage';
      case ConnectivityRiskEvidenceType.terrain:
        return 'terrain';
      case ConnectivityRiskEvidenceType.settlementDensity:
        return 'settlement_density';
      case ConnectivityRiskEvidenceType.roadIsolation:
        return 'road_isolation';
      case ConnectivityRiskEvidenceType.manual:
        return 'manual';
    }
  }

  String get label {
    switch (this) {
      case ConnectivityRiskEvidenceType.mobileCoverage:
        return 'Phủ sóng di động';
      case ConnectivityRiskEvidenceType.terrain:
        return 'Địa hình';
      case ConnectivityRiskEvidenceType.settlementDensity:
        return 'Mật độ khu dân cư';
      case ConnectivityRiskEvidenceType.roadIsolation:
        return 'Mức độ biệt lập của tuyến';
      case ConnectivityRiskEvidenceType.manual:
        return 'Đánh giá thủ công';
    }
  }
}

class ConnectivityRiskEvidence {
  const ConnectivityRiskEvidence({
    required this.type,
    required this.riskScore,
    required this.confidence,
    required this.source,
    this.description,
  }) : assert(riskScore >= 0 && riskScore <= 1),
       assert(confidence >= 0 && confidence <= 1);

  final ConnectivityRiskEvidenceType type;

  /// Điểm rủi ro chuẩn hóa:
  /// 0.0 = rủi ro thấp nhất
  /// 1.0 = rủi ro cao nhất
  final double riskScore;

  /// Độ tin cậy của bằng chứng:
  /// 0.0 = không đáng tin cậy
  /// 1.0 = độ tin cậy cao
  final double confidence;

  /// Nguồn dữ liệu, ví dụ:
  /// "manual", "provider_x", "cached_dataset".
  final String source;

  final String? description;
}

class ConnectivityRiskPoint {
  const ConnectivityRiskPoint({
    required this.latitude,
    required this.longitude,
    required this.distanceFromStartMeters,
    required this.progressRatio,
    required this.riskScore,
    required this.level,
    this.evidence = const [],
  }) : assert(latitude >= -90 && latitude <= 90),
       assert(longitude >= -180 && longitude <= 180),
       assert(distanceFromStartMeters >= 0),
       assert(progressRatio >= 0 && progressRatio <= 1),
       assert(riskScore >= 0 && riskScore <= 1);

  final double latitude;
  final double longitude;

  /// Vị trí của điểm tính từ đầu tuyến.
  final double distanceFromStartMeters;

  /// Tiến độ trên tuyến từ 0.0 đến 1.0.
  final double progressRatio;

  /// Điểm rủi ro chuẩn hóa từ 0.0 đến 1.0.
  final double riskScore;

  final ConnectivityRiskLevel level;

  final List<ConnectivityRiskEvidence> evidence;

  double get distanceFromStartKm => distanceFromStartMeters / 1000;

  double get progressPercent => progressRatio * 100;

  bool get requiresWarning => level.requiresWarning;
}

class ConnectivityRiskSegment {
  const ConnectivityRiskSegment({
    required this.startDistanceMeters,
    required this.endDistanceMeters,
    required this.startProgressRatio,
    required this.endProgressRatio,
    required this.averageRiskScore,
    required this.maxRiskScore,
    required this.level,
    this.sampleCount = 0,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
  }) : assert(startDistanceMeters >= 0),
       assert(endDistanceMeters >= startDistanceMeters),
       assert(startProgressRatio >= 0 && startProgressRatio <= 1),
       assert(endProgressRatio >= startProgressRatio && endProgressRatio <= 1),
       assert(averageRiskScore >= 0 && averageRiskScore <= 1),
       assert(maxRiskScore >= 0 && maxRiskScore <= 1),
       assert(sampleCount >= 0);

  final double startDistanceMeters;
  final double endDistanceMeters;

  final double startProgressRatio;
  final double endProgressRatio;

  final double averageRiskScore;
  final double maxRiskScore;

  final ConnectivityRiskLevel level;

  final int sampleCount;

  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;

  double get lengthMeters => endDistanceMeters - startDistanceMeters;

  double get lengthKm => lengthMeters / 1000;

  double get startDistanceKm => startDistanceMeters / 1000;

  double get endDistanceKm => endDistanceMeters / 1000;

  bool get requiresWarning => level.requiresWarning;
}

class ConnectivityRiskAssessment {
  const ConnectivityRiskAssessment({
    required this.totalRouteMeters,
    required this.overallRiskScore,
    required this.overallLevel,
    required this.segments,
    this.sampledPoints = const [],
    this.provider = 'unknown',
    this.generatedAt,
  }) : assert(totalRouteMeters >= 0),
       assert(overallRiskScore >= 0 && overallRiskScore <= 1);

  final double totalRouteMeters;

  final double overallRiskScore;

  final ConnectivityRiskLevel overallLevel;

  final List<ConnectivityRiskSegment> segments;

  final List<ConnectivityRiskPoint> sampledPoints;

  final String provider;

  final DateTime? generatedAt;

  double get totalRouteKm => totalRouteMeters / 1000;

  bool get hasRiskData => sampledPoints.isNotEmpty || segments.isNotEmpty;

  bool get hasWarningSegments =>
      segments.any((segment) => segment.requiresWarning);

  List<ConnectivityRiskSegment> get warningSegments =>
      List<ConnectivityRiskSegment>.unmodifiable(
        segments.where((segment) => segment.requiresWarning),
      );

  double get warningDistanceMeters {
    return segments
        .where((segment) => segment.requiresWarning)
        .fold<double>(0, (sum, segment) => sum + segment.lengthMeters);
  }

  double get warningDistanceKm => warningDistanceMeters / 1000;

  double get warningRouteRatio {
    if (totalRouteMeters <= 0) {
      return 0;
    }

    return (warningDistanceMeters / totalRouteMeters).clamp(0.0, 1.0);
  }

  double get warningRoutePercent => warningRouteRatio * 100;

  ConnectivityRiskSegment? get highestRiskSegment {
    if (segments.isEmpty) {
      return null;
    }

    var result = segments.first;

    for (final segment in segments.skip(1)) {
      if (segment.level.severity > result.level.severity) {
        result = segment;
        continue;
      }

      if (segment.level.severity == result.level.severity &&
          segment.maxRiskScore > result.maxRiskScore) {
        result = segment;
      }
    }

    return result;
  }
}
