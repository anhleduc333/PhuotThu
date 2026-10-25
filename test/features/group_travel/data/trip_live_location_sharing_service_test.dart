import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/data/group_trip_repository.dart';
import 'package:phuotthu/features/group_travel/data/trip_live_location_publisher.dart';
import 'package:phuotthu/features/group_travel/data/trip_live_location_repository.dart';
import 'package:phuotthu/features/group_travel/data/trip_live_location_sharing_service.dart';
import 'package:phuotthu/features/group_travel/data/trip_location_source.dart';
import 'package:phuotthu/features/group_travel/domain/group_trip_state.dart';
import 'package:phuotthu/features/group_travel/domain/trip_device_location.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_location.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member_view.dart';

void main() {
  test('enable updates consent then starts publisher', () async {
    final groupRepository = _FakeGroupRepository();
    final source = _FakeLocationSource();
    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: groupRepository,
      publisher: publisher,
    );

    final result = await service.setEnabled(tripId: 'trip-1', enabled: true);

    expect(result, TripLiveLocationSharingResult.enabled);
    expect(groupRepository.sharingChanges, [true]);
    expect(publisher.isRunning, isTrue);

    await publisher.dispose();
    await source.dispose();
  });

  test('permission denial rolls consent back to off', () async {
    final groupRepository = _FakeGroupRepository();
    final source = _FakeLocationSource(
      accessStatus: TripLocationAccessStatus.permissionDenied,
    );

    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: groupRepository,
      publisher: publisher,
    );

    final result = await service.setEnabled(tripId: 'trip-1', enabled: true);

    expect(result, TripLiveLocationSharingResult.permissionDenied);
    expect(groupRepository.sharingChanges, [true, false]);
    expect(publisher.isRunning, isFalse);

    await publisher.dispose();
    await source.dispose();
  });

  test('service disabled rolls consent back to off', () async {
    final groupRepository = _FakeGroupRepository();
    final source = _FakeLocationSource(
      accessStatus: TripLocationAccessStatus.serviceDisabled,
    );

    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: groupRepository,
      publisher: publisher,
    );

    final result = await service.setEnabled(tripId: 'trip-1', enabled: true);

    expect(result, TripLiveLocationSharingResult.serviceDisabled);
    expect(groupRepository.sharingChanges, [true, false]);

    await publisher.dispose();
    await source.dispose();
  });

  test('disable stops publisher and disables consent', () async {
    final groupRepository = _FakeGroupRepository();
    final source = _FakeLocationSource();

    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: groupRepository,
      publisher: publisher,
    );

    await service.setEnabled(tripId: 'trip-1', enabled: true);

    groupRepository.sharingChanges.clear();

    final result = await service.setEnabled(tripId: 'trip-1', enabled: false);

    expect(result, TripLiveLocationSharingResult.disabled);
    expect(groupRepository.sharingChanges, [false]);
    expect(publisher.isRunning, isFalse);

    await publisher.dispose();
    await source.dispose();
  });

  test('resume starts publisher without changing consent', () async {
    final groupRepository = _FakeGroupRepository();
    final source = _FakeLocationSource();

    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: groupRepository,
      publisher: publisher,
    );

    final result = await service.resumeIfEnabled(
      tripId: 'trip-1',
      enabled: true,
    );

    expect(result, TripLiveLocationSharingResult.enabled);
    expect(groupRepository.sharingChanges, isEmpty);
    expect(publisher.isRunning, isTrue);

    await publisher.dispose();
    await source.dispose();
  });

  test('resume false stops matching publisher', () async {
    final groupRepository = _FakeGroupRepository();
    final source = _FakeLocationSource();

    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: groupRepository,
      publisher: publisher,
    );

    await publisher.start('trip-1');

    final result = await service.resumeIfEnabled(
      tripId: 'trip-1',
      enabled: false,
    );

    expect(result, TripLiveLocationSharingResult.disabled);
    expect(publisher.isRunning, isFalse);

    await publisher.dispose();
    await source.dispose();
  });

  test('empty trip id is rejected', () async {
    final source = _FakeLocationSource();
    final publisher = TripLiveLocationPublisher(
      locationSource: source,
      repository: _FakeLiveRepository(),
    );

    final service = TripLiveLocationSharingService(
      groupRepository: _FakeGroupRepository(),
      publisher: publisher,
    );

    expect(
      () => service.setEnabled(tripId: ' ', enabled: true),
      throwsArgumentError,
    );

    await publisher.dispose();
    await source.dispose();
  });
}

class _FakeGroupRepository implements GroupTripRepository {
  final List<bool> sharingChanges = [];

  @override
  Future<void> setMyLocationSharing({
    required String tripId,
    required bool enabled,
  }) async {
    sharingChanges.add(enabled);
  }

  @override
  Future<GroupTripState> enableGroupTrip(String tripId) {
    throw UnimplementedError();
  }

  @override
  Future<GroupTripState> getGroupTripState(String tripId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TripMemberView>> getMemberViews(String tripId) {
    throw UnimplementedError();
  }

  @override
  Future<void> leaveTrip(String tripId) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeMember({
    required String tripId,
    required String memberUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> setMemberRole({
    required String tripId,
    required String memberUserId,
    required TripMemberRole role,
  }) {
    throw UnimplementedError();
  }
}

class _FakeLocationSource implements TripLocationSource {
  _FakeLocationSource({this.accessStatus = TripLocationAccessStatus.ready});

  final TripLocationAccessStatus accessStatus;

  final StreamController<TripDeviceLocation> _controller =
      StreamController<TripDeviceLocation>.broadcast();

  @override
  Future<TripLocationAccessResult> ensureAccess() async {
    return TripLocationAccessResult(status: accessStatus);
  }

  @override
  Stream<TripDeviceLocation> watchLocations() {
    return _controller.stream;
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class _FakeLiveRepository implements TripLiveLocationRepository {
  @override
  Future<void> clearMyLocation(String tripId) async {}

  @override
  Future<void> publishMyLocation(TripLiveLocationUpdate update) async {}

  @override
  Stream<List<TripLiveLocation>> watchTripLocations(String tripId) {
    return const Stream<List<TripLiveLocation>>.empty();
  }
}
