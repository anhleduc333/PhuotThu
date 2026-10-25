import 'group_trip_repository.dart';
import 'trip_live_location_publisher.dart';
import 'trip_location_source.dart';

enum TripLiveLocationSharingResult {
  enabled,
  disabled,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

extension TripLiveLocationSharingResultX on TripLiveLocationSharingResult {
  bool get isEnabled => this == TripLiveLocationSharingResult.enabled;

  String get label {
    switch (this) {
      case TripLiveLocationSharingResult.enabled:
        return 'Đang chia sẻ vị trí trực tiếp';
      case TripLiveLocationSharingResult.disabled:
        return 'Đã tắt chia sẻ vị trí';
      case TripLiveLocationSharingResult.serviceDisabled:
        return 'Dịch vụ vị trí đang tắt';
      case TripLiveLocationSharingResult.permissionDenied:
        return 'Chưa cấp quyền vị trí';
      case TripLiveLocationSharingResult.permissionDeniedForever:
        return 'Quyền vị trí bị từ chối vĩnh viễn';
    }
  }
}

class TripLiveLocationSharingService {
  TripLiveLocationSharingService({
    required this._groupRepository,
    required this._publisher,
  });

  final GroupTripRepository _groupRepository;
  final TripLiveLocationPublisher _publisher;

  Future<TripLiveLocationSharingResult> setEnabled({
    required String tripId,
    required bool enabled,
  }) async {
    final normalizedTripId = _normalizeTripId(tripId);

    if (enabled) {
      return _enable(normalizedTripId);
    }

    return _disable(normalizedTripId);
  }

  Future<TripLiveLocationSharingResult?> resumeIfEnabled({
    required String tripId,
    required bool enabled,
  }) async {
    final normalizedTripId = _normalizeTripId(tripId);

    if (!enabled) {
      if (_publisher.status.tripId == normalizedTripId) {
        await _publisher.stop(clearRemote: false);
      }

      return TripLiveLocationSharingResult.disabled;
    }

    if (_publisher.isRunning && _publisher.status.tripId == normalizedTripId) {
      return TripLiveLocationSharingResult.enabled;
    }

    final access = await _publisher.start(normalizedTripId);

    return _resultForAccess(access.status);
  }

  Future<TripLiveLocationSharingResult> _enable(String tripId) async {
    await _groupRepository.setMyLocationSharing(tripId: tripId, enabled: true);

    try {
      final access = await _publisher.start(tripId);

      if (access.canReadLocation) {
        return TripLiveLocationSharingResult.enabled;
      }

      await _publisher.stop(clearRemote: false);

      await _groupRepository.setMyLocationSharing(
        tripId: tripId,
        enabled: false,
      );

      return _resultForAccess(access.status);
    } catch (_) {
      await _bestEffortStopPublisher();

      await _bestEffortRollbackConsent(tripId);

      rethrow;
    }
  }

  Future<TripLiveLocationSharingResult> _disable(String tripId) async {
    final wasPublishingThisTrip = _publisher.status.tripId == tripId;

    if (wasPublishingThisTrip) {
      await _publisher.stop(clearRemote: false);
    }

    try {
      await _groupRepository.setMyLocationSharing(
        tripId: tripId,
        enabled: false,
      );
    } catch (_) {
      if (wasPublishingThisTrip) {
        try {
          await _publisher.start(tripId);
        } catch (_) {
          // Best-effort restore only. Preserve the original backend error.
        }
      }

      rethrow;
    }

    return TripLiveLocationSharingResult.disabled;
  }

  Future<void> _bestEffortStopPublisher() async {
    try {
      await _publisher.stop(clearRemote: false);
    } catch (_) {
      // Preserve the original enable error.
    }
  }

  Future<void> _bestEffortRollbackConsent(String tripId) async {
    try {
      await _groupRepository.setMyLocationSharing(
        tripId: tripId,
        enabled: false,
      );
    } catch (_) {
      // Preserve the original enable error.
    }
  }

  TripLiveLocationSharingResult _resultForAccess(
    TripLocationAccessStatus status,
  ) {
    switch (status) {
      case TripLocationAccessStatus.ready:
        return TripLiveLocationSharingResult.enabled;
      case TripLocationAccessStatus.serviceDisabled:
        return TripLiveLocationSharingResult.serviceDisabled;
      case TripLocationAccessStatus.permissionDenied:
        return TripLiveLocationSharingResult.permissionDenied;
      case TripLocationAccessStatus.permissionDeniedForever:
        return TripLiveLocationSharingResult.permissionDeniedForever;
    }
  }

  String _normalizeTripId(String tripId) {
    final normalized = tripId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    return normalized;
  }
}
