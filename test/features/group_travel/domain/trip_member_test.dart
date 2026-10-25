import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member.dart';

void main() {
  group('TripMemberRole', () {
    test('uses stable backend keys', () {
      expect(TripMemberRole.owner.key, 'owner');
      expect(TripMemberRole.leader.key, 'leader');
      expect(TripMemberRole.member.key, 'member');
    });

    test('owner and leader can manage members', () {
      expect(TripMemberRole.owner.canManageMembers, isTrue);
      expect(TripMemberRole.leader.canManageMembers, isTrue);
      expect(TripMemberRole.member.canManageMembers, isFalse);
      expect(TripMemberRole.owner.canTransferOwnership, isTrue);
      expect(TripMemberRole.leader.canTransferOwnership, isFalse);
    });

    test('parses roles and rejects unknown values', () {
      expect(tripMemberRoleFromKey(' LEADER '), TripMemberRole.leader);
      expect(() => tripMemberRoleFromKey('admin'), throwsFormatException);
    });
  });

  group('TripMember', () {
    TripMember member({
      TripMemberRole role = TripMemberRole.member,
      TripMemberStatus status = TripMemberStatus.active,
      bool locationSharing = false,
    }) {
      return TripMember(
        id: 'member-1',
        tripId: 'trip-1',
        userId: 'user-1',
        role: role,
        status: status,
        locationSharing: locationSharing,
        joinedAt: DateTime.utc(2026, 10, 25, 1),
      );
    }

    test('active owner cannot leave and can manage trip', () {
      final value = member(role: TripMemberRole.owner);

      expect(value.isOwner, isTrue);
      expect(value.canManageTrip, isTrue);
      expect(value.canManageMembers, isTrue);
      expect(value.canLeave, isFalse);
    });

    test('active normal member can leave but not manage', () {
      final value = member();

      expect(value.canLeave, isTrue);
      expect(value.canManageTrip, isFalse);
      expect(value.canManageMembers, isFalse);
    });

    test('location sharing requires active membership and opt-in', () {
      expect(member(locationSharing: true).canShareLocation, isTrue);
      expect(
        member(
          status: TripMemberStatus.left,
          locationSharing: true,
        ).canShareLocation,
        isFalse,
      );
      expect(member(locationSharing: false).canShareLocation, isFalse);
    });

    test('round trips JSON and normalizes timestamps to UTC', () {
      final original = TripMember(
        id: 'member-1',
        tripId: 'trip-1',
        userId: 'user-1',
        role: TripMemberRole.leader,
        status: TripMemberStatus.active,
        locationSharing: true,
        joinedAt: DateTime.parse('2026-10-25T10:00:00+07:00'),
        updatedAt: DateTime.parse('2026-10-25T11:00:00+07:00'),
      );

      final decoded = TripMember.fromJson(original.toJson());

      expect(decoded.role, TripMemberRole.leader);
      expect(decoded.locationSharing, isTrue);
      expect(decoded.joinedAt.isUtc, isTrue);
      expect(decoded.joinedAt.hour, 3);
      expect(decoded.updatedAt!.isUtc, isTrue);
      expect(decoded.updatedAt!.hour, 4);
    });

    test('parses status and rejects malformed status', () {
      expect(tripMemberStatusFromKey('removed'), TripMemberStatus.removed);
      expect(() => tripMemberStatusFromKey('blocked'), throwsFormatException);
    });

    test('rejects malformed JSON', () {
      expect(
        () => TripMember.fromJson({
          'id': '',
          'trip_id': 'trip-1',
          'user_id': 'user-1',
          'role': 'member',
          'status': 'active',
          'location_sharing': false,
          'joined_at': '2026-10-25T00:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });
}
