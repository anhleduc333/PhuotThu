import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_invitation.dart';

void main() {
  group('TripInvitationRole', () {
    test('does not expose owner as an invitation role', () {
      expect(TripInvitationRole.values.map((role) => role.key), [
        'leader',
        'member',
      ]);
    });

    test('parses invitation role and rejects invalid role', () {
      expect(tripInvitationRoleFromKey(' MEMBER '), TripInvitationRole.member);
      expect(() => tripInvitationRoleFromKey('owner'), throwsFormatException);
    });
  });

  group('TripInvitation', () {
    TripInvitation invitation({
      TripInvitationStatus status = TripInvitationStatus.pending,
      DateTime? expiresAt,
    }) {
      return TripInvitation(
        id: 'invite-1',
        tripId: 'trip-1',
        inviterId: 'owner-1',
        inviteeUserId: 'user-2',
        role: TripInvitationRole.member,
        status: status,
        createdAt: DateTime.utc(2026, 10, 25, 1),
        expiresAt: expiresAt ?? DateTime.utc(2026, 11, 1),
      );
    }

    test('pending invitation before expiry is actionable', () {
      final value = invitation();

      expect(value.isActionableAt(DateTime.utc(2026, 10, 30)), isTrue);
    });

    test('invitation at expiry time is expired', () {
      final value = invitation(expiresAt: DateTime.utc(2026, 10, 30));

      expect(value.isExpiredAt(DateTime.utc(2026, 10, 30)), isTrue);
      expect(value.isActionableAt(DateTime.utc(2026, 10, 30)), isFalse);
    });

    test('accepted invitation is not actionable', () {
      final value = invitation(status: TripInvitationStatus.accepted);

      expect(value.isActionableAt(DateTime.utc(2026, 10, 26)), isFalse);
    });

    test('round trips JSON and UTC timestamps', () {
      final original = TripInvitation(
        id: 'invite-1',
        tripId: 'trip-1',
        inviterId: 'owner-1',
        inviteeUserId: 'user-2',
        role: TripInvitationRole.leader,
        status: TripInvitationStatus.pending,
        createdAt: DateTime.parse('2026-10-25T10:00:00+07:00'),
        expiresAt: DateTime.parse('2026-11-01T10:00:00+07:00'),
      );

      final decoded = TripInvitation.fromJson(original.toJson());

      expect(decoded.role, TripInvitationRole.leader);
      expect(decoded.createdAt.isUtc, isTrue);
      expect(decoded.createdAt.hour, 3);
      expect(decoded.expiresAt.isUtc, isTrue);
      expect(decoded.expiresAt.hour, 3);
    });

    test('status parser supports all stable backend values', () {
      for (final status in TripInvitationStatus.values) {
        expect(tripInvitationStatusFromKey(status.key), status);
      }
    });

    test('rejects owner invitation role from JSON', () {
      expect(
        () => TripInvitation.fromJson({
          'id': 'invite-1',
          'trip_id': 'trip-1',
          'inviter_id': 'owner-1',
          'invitee_user_id': 'user-2',
          'role': 'owner',
          'status': 'pending',
          'created_at': '2026-10-25T00:00:00Z',
          'expires_at': '2026-11-01T00:00:00Z',
        }),
        throwsFormatException,
      );
    });

    test('copyWith can clear respondedAt', () {
      final initial = TripInvitation(
        id: 'invite-1',
        tripId: 'trip-1',
        inviterId: 'owner-1',
        inviteeUserId: 'user-2',
        role: TripInvitationRole.member,
        status: TripInvitationStatus.declined,
        createdAt: DateTime.utc(2026, 10, 25),
        expiresAt: DateTime.utc(2026, 11, 1),
        respondedAt: DateTime.utc(2026, 10, 26),
      );

      final cleared = initial.copyWith(clearRespondedAt: true);

      expect(cleared.respondedAt, isNull);
    });
  });
}
