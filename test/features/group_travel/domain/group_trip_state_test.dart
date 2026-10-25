import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/group_trip_state.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member.dart';

void main() {
  TripMember member({
    required String id,
    required String userId,
    TripMemberRole role = TripMemberRole.member,
    TripMemberStatus status = TripMemberStatus.active,
    bool sharing = false,
  }) {
    return TripMember(
      id: id,
      tripId: 'trip-1',
      userId: userId,
      role: role,
      status: status,
      locationSharing: sharing,
      joinedAt: DateTime.utc(2026, 10, 25),
    );
  }

  GroupTripState state({
    String viewerUserId = 'owner-1',
    bool enabled = true,
    List<TripMember>? members,
  }) {
    return GroupTripState(
      tripId: 'trip-1',
      ownerId: 'owner-1',
      viewerUserId: viewerUserId,
      isGroupEnabled: enabled,
      members:
          members ??
          [
            member(
              id: 'm-owner',
              userId: 'owner-1',
              role: TripMemberRole.owner,
            ),
          ],
    );
  }

  test('owner can manage members even when membership exists', () {
    final value = state();

    expect(value.viewerIsOwner, isTrue);
    expect(value.viewerIsActiveMember, isTrue);
    expect(value.viewerCanManageMembers, isTrue);
  });

  test('active leader can manage members', () {
    final value = state(
      viewerUserId: 'leader-1',
      members: [
        member(id: 'm-owner', userId: 'owner-1', role: TripMemberRole.owner),
        member(id: 'm-leader', userId: 'leader-1', role: TripMemberRole.leader),
      ],
    );

    expect(value.viewerIsOwner, isFalse);
    expect(value.viewerIsActiveMember, isTrue);
    expect(value.viewerCanManageMembers, isTrue);
  });

  test('normal member cannot manage members', () {
    final value = state(
      viewerUserId: 'member-1',
      members: [
        member(id: 'm-owner', userId: 'owner-1', role: TripMemberRole.owner),
        member(id: 'm-member', userId: 'member-1'),
      ],
    );

    expect(value.viewerIsActiveMember, isTrue);
    expect(value.viewerCanManageMembers, isFalse);
  });

  test('left member is not considered active viewer', () {
    final value = state(
      viewerUserId: 'member-1',
      members: [
        member(id: 'm-owner', userId: 'owner-1', role: TripMemberRole.owner),
        member(
          id: 'm-member',
          userId: 'member-1',
          status: TripMemberStatus.left,
        ),
      ],
    );

    expect(value.viewerIsActiveMember, isFalse);
    expect(value.viewerCanManageMembers, isFalse);
  });

  test('counts only active members', () {
    final value = state(
      members: [
        member(id: 'm-owner', userId: 'owner-1', role: TripMemberRole.owner),
        member(id: 'm-leader', userId: 'leader-1', role: TripMemberRole.leader),
        member(id: 'm-member', userId: 'member-1'),
        member(id: 'm-left', userId: 'member-2', status: TripMemberStatus.left),
      ],
    );

    expect(value.activeMemberCount, 3);
    expect(value.activeNonOwnerMemberCount, 2);
    expect(value.activeLeaderCount, 1);
    expect(value.hasOtherActiveMembers, isTrue);
  });

  test('location sharing count requires active opt-in', () {
    final value = state(
      members: [
        member(
          id: 'm-owner',
          userId: 'owner-1',
          role: TripMemberRole.owner,
          sharing: false,
        ),
        member(id: 'm-1', userId: 'member-1', sharing: true),
        member(
          id: 'm-2',
          userId: 'member-2',
          sharing: true,
          status: TripMemberStatus.removed,
        ),
      ],
    );

    expect(value.locationSharingMemberCount, 1);
  });

  test('enabled group with only owner is solo group', () {
    final value = state(enabled: true);

    expect(value.isSoloGroup, isTrue);
    expect(value.hasOtherActiveMembers, isFalse);
  });

  test('disabled trip is not solo group', () {
    final value = state(enabled: false);

    expect(value.isSoloGroup, isFalse);
  });
}
