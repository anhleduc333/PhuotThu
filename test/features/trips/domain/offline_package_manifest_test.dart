import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/trips/domain/offline_package_manifest.dart';

void main() {
  OfflinePackageArtifact artifact({
    required OfflinePackageArtifactType type,
    required OfflinePackageArtifactStatus status,
    bool required = false,
    int version = 1,
    int? sizeBytes,
    int? itemCount,
    DateTime? expiresAt,
  }) {
    return OfflinePackageArtifact(
      type: type,
      status: status,
      isRequired: required,
      version: version,
      sizeBytes: sizeBytes,
      itemCount: itemCount,
      expiresAt: expiresAt,
    );
  }

  group('OfflinePackageArtifact', () {
    test('ready artifact is usable when not expired', () {
      final value = artifact(
        type: OfflinePackageArtifactType.routeGeometry,
        status: OfflinePackageArtifactStatus.ready,
        required: true,
        expiresAt: DateTime.utc(2026, 10, 26),
      );

      expect(value.isUsableAt(DateTime.utc(2026, 10, 25)), isTrue);
      expect(value.blocksPackage, isFalse);
    });

    test('expired ready artifact is not usable', () {
      final value = artifact(
        type: OfflinePackageArtifactType.routeGeometry,
        status: OfflinePackageArtifactStatus.ready,
        required: true,
        expiresAt: DateTime.utc(2026, 10, 25),
      );

      expect(value.isExpiredAt(DateTime.utc(2026, 10, 25)), isTrue);
      expect(value.isUsableAt(DateTime.utc(2026, 10, 25)), isFalse);
    });

    test('missing required artifact blocks package', () {
      final value = artifact(
        type: OfflinePackageArtifactType.tripDetails,
        status: OfflinePackageArtifactStatus.missing,
        required: true,
      );

      expect(value.blocksPackage, isTrue);
      expect(value.requiresRefresh, isTrue);
    });

    test('optional missing artifact does not block package', () {
      final value = artifact(
        type: OfflinePackageArtifactType.offlineMapMetadata,
        status: OfflinePackageArtifactStatus.missing,
      );

      expect(value.blocksPackage, isFalse);
      expect(value.requiresRefresh, isTrue);
    });

    test('converts bytes to MB', () {
      final value = artifact(
        type: OfflinePackageArtifactType.routeGeometry,
        status: OfflinePackageArtifactStatus.ready,
        sizeBytes: 4 * 1024 * 1024,
      );

      expect(value.sizeMb, 4);
    });

    test('copyWith preserves unchanged values', () {
      final value = OfflinePackageArtifact(
        type: OfflinePackageArtifactType.essentialPois,
        status: OfflinePackageArtifactStatus.missing,
        isRequired: true,
        version: 2,
        cacheKey: 'trip:poi',
        contentHash: 'abc',
        sizeBytes: 100,
      );

      final updated = value.copyWith(
        status: OfflinePackageArtifactStatus.ready,
      );

      expect(updated.status, OfflinePackageArtifactStatus.ready);
      expect(updated.type, value.type);
      expect(updated.version, 2);
      expect(updated.cacheKey, 'trip:poi');
      expect(updated.contentHash, 'abc');
      expect(updated.sizeBytes, 100);
    });
  });

  group('OfflinePackageManifest', () {
    final createdAt = DateTime.utc(2026, 10, 25, 1);
    final updatedAt = DateTime.utc(2026, 10, 25, 2);

    test('reports complete package when all required artifacts are ready', () {
      final manifest = OfflinePackageManifest(
        tripId: 'trip-1',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
        artifacts: [
          artifact(
            type: OfflinePackageArtifactType.tripDetails,
            status: OfflinePackageArtifactStatus.ready,
            required: true,
          ),
          artifact(
            type: OfflinePackageArtifactType.routeGeometry,
            status: OfflinePackageArtifactStatus.ready,
            required: true,
          ),
          artifact(
            type: OfflinePackageArtifactType.offlineMapMetadata,
            status: OfflinePackageArtifactStatus.missing,
          ),
        ],
      );

      expect(manifest.isComplete, isTrue);
      expect(manifest.blockingArtifacts, isEmpty);
      expect(manifest.requiredCompletionPercent, 100);
    });

    test('reports incomplete package when required artifact is missing', () {
      final manifest = OfflinePackageManifest(
        tripId: 'trip-1',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
        artifacts: [
          artifact(
            type: OfflinePackageArtifactType.tripDetails,
            status: OfflinePackageArtifactStatus.ready,
            required: true,
          ),
          artifact(
            type: OfflinePackageArtifactType.routeGeometry,
            status: OfflinePackageArtifactStatus.missing,
            required: true,
          ),
        ],
      );

      expect(manifest.isComplete, isFalse);
      expect(manifest.blockingArtifacts.length, 1);
      expect(manifest.requiredCompletionRatio, 0.5);
    });

    test('sums package size and item count', () {
      final manifest = OfflinePackageManifest(
        tripId: 'trip-1',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
        artifacts: [
          artifact(
            type: OfflinePackageArtifactType.routeGeometry,
            status: OfflinePackageArtifactStatus.ready,
            sizeBytes: 2 * 1024 * 1024,
            itemCount: 120,
          ),
          artifact(
            type: OfflinePackageArtifactType.essentialPois,
            status: OfflinePackageArtifactStatus.ready,
            sizeBytes: 3 * 1024 * 1024,
            itemCount: 25,
          ),
        ],
      );

      expect(manifest.totalSizeBytes, 5 * 1024 * 1024);
      expect(manifest.totalSizeMb, 5);
      expect(manifest.totalItemCount, 145);
    });

    test('finds artifact by type', () {
      final manifest = OfflinePackageManifest(
        tripId: 'trip-1',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
        artifacts: [
          artifact(
            type: OfflinePackageArtifactType.emergencyInfo,
            status: OfflinePackageArtifactStatus.ready,
          ),
        ],
      );

      expect(
        manifest.artifactOf(OfflinePackageArtifactType.emergencyInfo),
        isNotNull,
      );

      expect(
        manifest.artifactOf(OfflinePackageArtifactType.routeSummary),
        isNull,
      );
    });

    test('detects expired required artifact', () {
      final manifest = OfflinePackageManifest(
        tripId: 'trip-1',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
        artifacts: [
          artifact(
            type: OfflinePackageArtifactType.connectivityRiskAnalysis,
            status: OfflinePackageArtifactStatus.ready,
            required: true,
            expiresAt: DateTime.utc(2026, 10, 24),
          ),
        ],
      );

      expect(
        manifest.hasExpiredRequiredArtifactAt(DateTime.utc(2026, 10, 25)),
        isTrue,
      );

      expect(manifest.isUsableAt(DateTime.utc(2026, 10, 25)), isFalse);
    });

    test('is usable when all required artifacts are ready and fresh', () {
      final manifest = OfflinePackageManifest(
        tripId: 'trip-1',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
        artifacts: [
          artifact(
            type: OfflinePackageArtifactType.tripDetails,
            status: OfflinePackageArtifactStatus.ready,
            required: true,
          ),
          artifact(
            type: OfflinePackageArtifactType.routeGeometry,
            status: OfflinePackageArtifactStatus.ready,
            required: true,
            expiresAt: DateTime.utc(2026, 10, 30),
          ),
          artifact(
            type: OfflinePackageArtifactType.offlineMapMetadata,
            status: OfflinePackageArtifactStatus.failed,
          ),
        ],
      );

      expect(manifest.isUsableAt(DateTime.utc(2026, 10, 25)), isTrue);
    });
  });
}
