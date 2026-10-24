enum OfflinePackageArtifactType {
  tripDetails,
  routeGeometry,
  routeSummary,
  essentialPois,
  emergencyInfo,
  connectivityRiskAnalysis,
  offlineMapMetadata,
}

extension OfflinePackageArtifactTypeX on OfflinePackageArtifactType {
  String get key {
    switch (this) {
      case OfflinePackageArtifactType.tripDetails:
        return 'trip_details';
      case OfflinePackageArtifactType.routeGeometry:
        return 'route_geometry';
      case OfflinePackageArtifactType.routeSummary:
        return 'route_summary';
      case OfflinePackageArtifactType.essentialPois:
        return 'essential_pois';
      case OfflinePackageArtifactType.emergencyInfo:
        return 'emergency_info';
      case OfflinePackageArtifactType.connectivityRiskAnalysis:
        return 'connectivity_risk_analysis';
      case OfflinePackageArtifactType.offlineMapMetadata:
        return 'offline_map_metadata';
    }
  }

  String get label {
    switch (this) {
      case OfflinePackageArtifactType.tripDetails:
        return 'Thông tin chuyến đi';
      case OfflinePackageArtifactType.routeGeometry:
        return 'Hình học tuyến đường';
      case OfflinePackageArtifactType.routeSummary:
        return 'Tóm tắt hành trình';
      case OfflinePackageArtifactType.essentialPois:
        return 'POI thiết yếu';
      case OfflinePackageArtifactType.emergencyInfo:
        return 'Thông tin khẩn cấp';
      case OfflinePackageArtifactType.connectivityRiskAnalysis:
        return 'Phân tích nguy cơ kết nối';
      case OfflinePackageArtifactType.offlineMapMetadata:
        return 'Thông tin bản đồ offline';
    }
  }
}

enum OfflinePackageArtifactStatus { missing, pending, ready, stale, failed }

extension OfflinePackageArtifactStatusX on OfflinePackageArtifactStatus {
  String get key {
    switch (this) {
      case OfflinePackageArtifactStatus.missing:
        return 'missing';
      case OfflinePackageArtifactStatus.pending:
        return 'pending';
      case OfflinePackageArtifactStatus.ready:
        return 'ready';
      case OfflinePackageArtifactStatus.stale:
        return 'stale';
      case OfflinePackageArtifactStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case OfflinePackageArtifactStatus.missing:
        return 'Chưa có';
      case OfflinePackageArtifactStatus.pending:
        return 'Đang chuẩn bị';
      case OfflinePackageArtifactStatus.ready:
        return 'Sẵn sàng';
      case OfflinePackageArtifactStatus.stale:
        return 'Cần cập nhật';
      case OfflinePackageArtifactStatus.failed:
        return 'Lỗi';
    }
  }

  bool get isUsable => this == OfflinePackageArtifactStatus.ready;

  bool get requiresRefresh =>
      this == OfflinePackageArtifactStatus.missing ||
      this == OfflinePackageArtifactStatus.stale ||
      this == OfflinePackageArtifactStatus.failed;
}

class OfflinePackageArtifact {
  const OfflinePackageArtifact({
    required this.type,
    required this.status,
    required this.isRequired,
    required this.version,
    this.cacheKey,
    this.contentHash,
    this.generatedAt,
    this.expiresAt,
    this.sizeBytes,
    this.itemCount,
    this.note,
  }) : assert(version >= 1),
       assert(sizeBytes == null || sizeBytes >= 0),
       assert(itemCount == null || itemCount >= 0);

  final OfflinePackageArtifactType type;
  final OfflinePackageArtifactStatus status;
  final bool isRequired;

  /// Version logic của artifact.
  final int version;

  /// Khóa cache/local storage sẽ được dùng ở DEV-08F.4.
  final String? cacheKey;

  /// Hash/checksum tùy chọn để phát hiện nội dung đã thay đổi.
  final String? contentHash;

  final DateTime? generatedAt;
  final DateTime? expiresAt;

  final int? sizeBytes;
  final int? itemCount;

  final String? note;

  bool get isReady => status == OfflinePackageArtifactStatus.ready;

  bool get blocksPackage =>
      isRequired && status != OfflinePackageArtifactStatus.ready;

  bool get requiresRefresh => status.requiresRefresh;

  bool isExpiredAt(DateTime now) {
    final expiry = expiresAt;

    if (expiry == null) {
      return false;
    }

    return !expiry.isAfter(now);
  }

  bool isUsableAt(DateTime now) {
    return isReady && !isExpiredAt(now);
  }

  double? get sizeMb {
    final bytes = sizeBytes;

    if (bytes == null) {
      return null;
    }

    return bytes / (1024 * 1024);
  }

  OfflinePackageArtifact copyWith({
    OfflinePackageArtifactType? type,
    OfflinePackageArtifactStatus? status,
    bool? isRequired,
    int? version,
    String? cacheKey,
    String? contentHash,
    DateTime? generatedAt,
    DateTime? expiresAt,
    int? sizeBytes,
    int? itemCount,
    String? note,
  }) {
    return OfflinePackageArtifact(
      type: type ?? this.type,
      status: status ?? this.status,
      isRequired: isRequired ?? this.isRequired,
      version: version ?? this.version,
      cacheKey: cacheKey ?? this.cacheKey,
      contentHash: contentHash ?? this.contentHash,
      generatedAt: generatedAt ?? this.generatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      itemCount: itemCount ?? this.itemCount,
      note: note ?? this.note,
    );
  }
}

class OfflinePackageManifest {
  const OfflinePackageManifest({
    required this.tripId,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.artifacts,
    this.routeFingerprint,
    this.packageId,
  }) : assert(schemaVersion >= 1);

  final String tripId;

  /// Version schema của manifest, độc lập với version từng artifact.
  final int schemaVersion;

  final DateTime createdAt;
  final DateTime updatedAt;

  final List<OfflinePackageArtifact> artifacts;

  /// Dùng để phát hiện route thay đổi và invalid cache ở DEV-08F.4.
  final String? routeFingerprint;

  /// ID tùy chọn nếu sau này package được lưu như một entity riêng.
  final String? packageId;

  List<OfflinePackageArtifact> get requiredArtifacts =>
      List<OfflinePackageArtifact>.unmodifiable(
        artifacts.where((artifact) => artifact.isRequired),
      );

  List<OfflinePackageArtifact> get readyArtifacts =>
      List<OfflinePackageArtifact>.unmodifiable(
        artifacts.where((artifact) => artifact.isReady),
      );

  List<OfflinePackageArtifact> get blockingArtifacts =>
      List<OfflinePackageArtifact>.unmodifiable(
        artifacts.where((artifact) => artifact.blocksPackage),
      );

  List<OfflinePackageArtifact> get refreshRequiredArtifacts =>
      List<OfflinePackageArtifact>.unmodifiable(
        artifacts.where((artifact) => artifact.requiresRefresh),
      );

  bool get isComplete => blockingArtifacts.isEmpty;

  int get requiredArtifactCount =>
      artifacts.where((artifact) => artifact.isRequired).length;

  int get readyRequiredArtifactCount => artifacts
      .where((artifact) => artifact.isRequired && artifact.isReady)
      .length;

  double get requiredCompletionRatio {
    final total = requiredArtifactCount;

    if (total == 0) {
      return 1;
    }

    return readyRequiredArtifactCount / total;
  }

  double get requiredCompletionPercent => requiredCompletionRatio * 100;

  int get totalSizeBytes {
    return artifacts.fold<int>(
      0,
      (sum, artifact) => sum + (artifact.sizeBytes ?? 0),
    );
  }

  double get totalSizeMb => totalSizeBytes / (1024 * 1024);

  int get totalItemCount {
    return artifacts.fold<int>(
      0,
      (sum, artifact) => sum + (artifact.itemCount ?? 0),
    );
  }

  OfflinePackageArtifact? artifactOf(OfflinePackageArtifactType type) {
    for (final artifact in artifacts) {
      if (artifact.type == type) {
        return artifact;
      }
    }

    return null;
  }

  bool hasExpiredRequiredArtifactAt(DateTime now) {
    return artifacts.any(
      (artifact) => artifact.isRequired && artifact.isExpiredAt(now),
    );
  }

  bool isUsableAt(DateTime now) {
    return artifacts
        .where((artifact) => artifact.isRequired)
        .every((artifact) => artifact.isUsableAt(now));
  }
}
