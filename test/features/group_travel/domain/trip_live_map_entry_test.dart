import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_location.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_map_entry.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member_view.dart';

void main() {
  const assembler = TripLiveMapEntryAssembler();

  TripMemberView member({
    required String userId,
    String tripId = 'trip-1',
    String displayName = 'Member',
    TripMemberRole role = TripMemberRole.member,
    bool locationSharing = true,
  }) {
    return TripMemberView(
      memberId: 'member-$userId',
      tripId: tripId,
      userId: userId,
      displayName: displayName,
      email: '$userId@example.com',
      role: role,
      locationSharing: locationSharing,
      joinedAt: DateTime.utc(2026, 10, 25),
    );
  }

  TripLiveLocation location({
    required String userId,
    String tripId = 'trip-1',
    double latitude = 21,
    double longitude = 105,
    int recordedSecond = 0,
  }) {
    return TripLiveLocation(
      id: 'location-$userId-$recordedSecond',
      tripId: tripId,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      recordedAt: DateTime.utc(2026, 10, 25, 3, 0, recordedSecond),
      updatedAt: DateTime.utc(2026, 10, 25, 3, 0, recordedSecond),
    );
  }

  test('joins sharing member with matching live location', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [member(userId: 'u1', displayName: 'Anh Le')],
      locations: [location(userId: 'u1')],
    );

    expect(result.length, 1);
    expect(result.single.userId, 'u1');
    expect(result.single.displayName, 'Anh Le');
  });

  test('does not expose member with sharing disabled', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [member(userId: 'u1', locationSharing: false)],
      locations: [location(userId: 'u1')],
    );

    expect(result, isEmpty);
  });

  test('ignores live location without member metadata', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [member(userId: 'u1')],
      locations: [location(userId: 'u2')],
    );

    expect(result, isEmpty);
  });

  test('ignores data from another trip', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [member(userId: 'u1', tripId: 'trip-2')],
      locations: [location(userId: 'u1', tripId: 'trip-2')],
    );

    expect(result, isEmpty);
  });

  test('uses newest duplicate location for same user', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [member(userId: 'u1')],
      locations: [
        location(userId: 'u1', latitude: 21.0, recordedSecond: 1),
        location(userId: 'u1', latitude: 21.5, recordedSecond: 2),
      ],
    );

    expect(result.single.location.latitude, 21.5);
  });

  test('sorts owner then leader then member', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [
        member(userId: 'm', displayName: 'Member'),
        member(userId: 'o', displayName: 'Owner', role: TripMemberRole.owner),
        member(userId: 'l', displayName: 'Leader', role: TripMemberRole.leader),
      ],
      locations: [
        location(userId: 'm'),
        location(userId: 'o'),
        location(userId: 'l'),
      ],
    );

    expect(result.map((entry) => entry.userId), ['o', 'l', 'm']);
  });

  test('sorts same-role members by display name', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [
        member(userId: 'b', displayName: 'Binh'),
        member(userId: 'a', displayName: 'Anh'),
      ],
      locations: [
        location(userId: 'b'),
        location(userId: 'a'),
      ],
    );

    expect(result.map((entry) => entry.displayName), ['Anh', 'Binh']);
  });

  test('entry delegates freshness to live location', () {
    final result = assembler.assemble(
      tripId: 'trip-1',
      members: [member(userId: 'u1')],
      locations: [location(userId: 'u1')],
    );

    expect(result.single.isFreshAt(DateTime.utc(2026, 10, 25, 3, 1)), isTrue);

    expect(result.single.isFreshAt(DateTime.utc(2026, 10, 25, 3, 3)), isFalse);
  });

  test('empty trip id is rejected', () {
    expect(
      () => assembler.assemble(
        tripId: '   ',
        members: const [],
        locations: const [],
      ),
      throwsArgumentError,
    );
  });
}
