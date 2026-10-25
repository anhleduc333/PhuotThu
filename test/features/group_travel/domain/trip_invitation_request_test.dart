import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_invitation.dart';
import 'package:phuotthu/features/group_travel/domain/trip_invitation_request.dart';

void main() {
  group('CreateTripInvitationInput', () {
    test('normalizes trip id and email', () {
      final input = CreateTripInvitationInput(
        tripId: ' trip-1 ',
        email: ' Rider@Example.COM ',
      );

      expect(input.tripId, 'trip-1');
      expect(input.email, 'rider@example.com');
      expect(input.role, TripInvitationRole.member);
    });

    test('supports leader invitation role', () {
      final input = CreateTripInvitationInput(
        tripId: 'trip-1',
        email: 'leader@example.com',
        role: TripInvitationRole.leader,
      );

      expect(input.role, TripInvitationRole.leader);
    });

    test('rejects empty trip id', () {
      expect(
        () => CreateTripInvitationInput(
          tripId: '   ',
          email: 'rider@example.com',
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty email', () {
      expect(
        () => CreateTripInvitationInput(tripId: 'trip-1', email: '   '),
        throwsArgumentError,
      );
    });

    test('rejects email without at sign', () {
      expect(
        () => CreateTripInvitationInput(
          tripId: 'trip-1',
          email: 'rider.example.com',
        ),
        throwsArgumentError,
      );
    });

    test('rejects email without domain suffix', () {
      expect(
        () =>
            CreateTripInvitationInput(tripId: 'trip-1', email: 'rider@example'),
        throwsArgumentError,
      );
    });

    test('rejects email containing spaces', () {
      expect(
        () => CreateTripInvitationInput(
          tripId: 'trip-1',
          email: 'rider name@example.com',
        ),
        throwsArgumentError,
      );
    });
  });
}
