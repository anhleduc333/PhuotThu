import 'dart:async';
import 'dart:math' as math;

import '../domain/trip_device_location.dart';
import '../domain/trip_live_location.dart';
import 'trip_live_location_repository.dart';
import 'trip_location_source.dart';

class TripLiveLocationPublishPolicy {
  const TripLiveLocationPublishPolicy({
    this.minPublishInterval = const Duration(seconds: 8),
    this.minDistanceMeters = 10,
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  final Duration minPublishInterval;
  final double minDistanceMeters;
  final Duration heartbeatInterval;

  bool get isValid {
    return !minPublishInterval.isNegative &&
        minDistanceMeters.isFinite &&
        minDistanceMeters >= 0 &&
        !heartbeatInterval.isNegative &&
        heartbeatInterval >= minPublishInterval;
  }

  bool shouldPublish({
    required TripDeviceLocation candidate,
    required TripDeviceLocation? lastPublished,
  }) {
    if (!isValid) {
      throw StateError('TripLiveLocationPublishPolicy không hợp lệ.');
    }

    if (!candidate.isValid) {
      return false;
    }

    if (lastPublished == null) {
      return true;
    }

    final candidateTime = candidate.measuredAt.toUtc();
    final previousTime = lastPublished.measuredAt.toUtc();

    if (!candidateTime.isAfter(previousTime)) {
      return false;
    }

    final elapsed = candidateTime.difference(previousTime);

    if (elapsed >= heartbeatInterval) {
      return true;
    }

    if (elapsed < minPublishInterval) {
      return false;
    }

    final distance = distanceMeters(
      lastPublished.latitude,
      lastPublished.longitude,
      candidate.latitude,
      candidate.longitude,
    );

    return distance >= minDistanceMeters;
  }

  static double distanceMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusMeters = 6371000.0;

    double radians(double degrees) {
      return degrees * math.pi / 180;
    }

    final lat1 = radians(latitudeA);
    final lat2 = radians(latitudeB);
    final deltaLat = radians(latitudeB - latitudeA);
    final deltaLon = radians(longitudeB - longitudeA);

    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);

    final a =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;

    final safeA = a.clamp(0.0, 1.0).toDouble();

    final c = 2 * math.atan2(math.sqrt(safeA), math.sqrt(1 - safeA));

    return earthRadiusMeters * c;
  }
}

enum TripLiveLocationPublisherState {
  idle,
  starting,
  running,
  stopped,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

class TripLiveLocationPublisherStatus {
  const TripLiveLocationPublisherStatus({
    required this.state,
    this.tripId,
    this.lastPublishedAt,
    this.publishCount = 0,
    this.error,
  });

  final TripLiveLocationPublisherState state;
  final String? tripId;
  final DateTime? lastPublishedAt;
  final int publishCount;
  final Object? error;

  bool get isRunning => state == TripLiveLocationPublisherState.running;
}

class TripLiveLocationPublisher {
  TripLiveLocationPublisher({
    required this._locationSource,
    required this._repository,
    this.policy = const TripLiveLocationPublishPolicy(),
  });

  final TripLocationSource _locationSource;
  final TripLiveLocationRepository _repository;
  final TripLiveLocationPublishPolicy policy;

  final StreamController<TripLiveLocationPublisherStatus> _statusController =
      StreamController<TripLiveLocationPublisherStatus>.broadcast();

  StreamSubscription<TripDeviceLocation>? _locationSubscription;

  Future<void> _pipeline = Future<void>.value();

  String? _tripId;
  TripDeviceLocation? _lastPublished;
  int _publishCount = 0;
  bool _disposed = false;

  TripLiveLocationPublisherStatus _status =
      const TripLiveLocationPublisherStatus(
        state: TripLiveLocationPublisherState.idle,
      );

  Stream<TripLiveLocationPublisherStatus> get statusStream =>
      _statusController.stream;

  TripLiveLocationPublisherStatus get status => _status;

  bool get isRunning => status.isRunning;

  Future<TripLocationAccessResult> start(String tripId) async {
    _ensureNotDisposed();

    final normalizedTripId = tripId.trim();

    if (normalizedTripId.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    if (!policy.isValid) {
      throw StateError('TripLiveLocationPublishPolicy không hợp lệ.');
    }

    await stop(clearRemote: false);

    _tripId = normalizedTripId;
    _lastPublished = null;
    _publishCount = 0;

    _emit(
      TripLiveLocationPublisherStatus(
        state: TripLiveLocationPublisherState.starting,
        tripId: normalizedTripId,
      ),
    );

    final access = await _locationSource.ensureAccess();

    if (!access.canReadLocation) {
      _emit(
        TripLiveLocationPublisherStatus(
          state: _publisherStateForAccess(access.status),
          tripId: normalizedTripId,
        ),
      );

      return access;
    }

    _locationSubscription = _locationSource.watchLocations().listen(
      (location) {
        _pipeline = _pipeline.then((_) => _handleLocation(location)).catchError(
          (Object error) {
            _emitFailure(error);
          },
        );
      },
      onError: (Object error) {
        _emitFailure(error);
      },
      cancelOnError: false,
    );

    _emit(
      TripLiveLocationPublisherStatus(
        state: TripLiveLocationPublisherState.running,
        tripId: normalizedTripId,
      ),
    );

    return access;
  }

  Future<void> _handleLocation(TripDeviceLocation location) async {
    final tripId = _tripId;

    if (tripId == null || _locationSubscription == null) {
      return;
    }

    if (!location.isValid) {
      return;
    }

    final normalized = location.normalized();

    if (!policy.shouldPublish(
      candidate: normalized,
      lastPublished: _lastPublished,
    )) {
      return;
    }

    await _repository.publishMyLocation(
      TripLiveLocationUpdate(
        tripId: tripId,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        accuracyMeters: normalized.accuracyMeters,
        speedMetersPerSecond: normalized.speedMetersPerSecond,
        headingDegrees: normalized.headingDegrees,
        recordedAt: normalized.measuredAt,
      ),
    );

    _lastPublished = normalized;
    _publishCount += 1;

    _emit(
      TripLiveLocationPublisherStatus(
        state: TripLiveLocationPublisherState.running,
        tripId: tripId,
        lastPublishedAt: normalized.measuredAt.toUtc(),
        publishCount: _publishCount,
      ),
    );
  }

  Future<void> stop({bool clearRemote = false}) async {
    if (_disposed) {
      return;
    }

    final tripId = _tripId;

    final subscription = _locationSubscription;

    _locationSubscription = null;

    if (subscription != null) {
      await subscription.cancel();
    }

    await flush();

    if (clearRemote && tripId != null && tripId.isNotEmpty) {
      await _repository.clearMyLocation(tripId);
    }

    _tripId = null;
    _lastPublished = null;
    _publishCount = 0;

    _emit(
      const TripLiveLocationPublisherStatus(
        state: TripLiveLocationPublisherState.stopped,
      ),
    );
  }

  Future<void> flush() async {
    await _pipeline;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    await stop(clearRemote: false);

    _disposed = true;

    await _statusController.close();
  }

  TripLiveLocationPublisherState _publisherStateForAccess(
    TripLocationAccessStatus status,
  ) {
    switch (status) {
      case TripLocationAccessStatus.ready:
        return TripLiveLocationPublisherState.running;
      case TripLocationAccessStatus.serviceDisabled:
        return TripLiveLocationPublisherState.serviceDisabled;
      case TripLocationAccessStatus.permissionDenied:
        return TripLiveLocationPublisherState.permissionDenied;
      case TripLocationAccessStatus.permissionDeniedForever:
        return TripLiveLocationPublisherState.permissionDeniedForever;
    }
  }

  void _emitFailure(Object error) {
    _emit(
      TripLiveLocationPublisherStatus(
        state: TripLiveLocationPublisherState.failed,
        tripId: _tripId,
        lastPublishedAt: _lastPublished?.measuredAt.toUtc(),
        publishCount: _publishCount,
        error: error,
      ),
    );
  }

  void _emit(TripLiveLocationPublisherStatus value) {
    _status = value;

    if (!_statusController.isClosed) {
      _statusController.add(value);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('TripLiveLocationPublisher đã dispose.');
    }
  }
}
